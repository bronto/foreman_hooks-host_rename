#!/usr/bin/env ruby
#
# Copyright 2015 Bronto Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

raise 'Unsupported version of Ruby' unless RUBY_VERSION >= '1.9.3'

require 'rubygems'
require 'minitest/autorun'
require 'stringio'
require 'tempfile'

class TestMain < MiniTest::Unit::TestCase
  require_relative '../lib/foreman_hooks/host_rename'

  # Wipe the database and reinitialize it
  def test_initialize_database
    hook = ForemanHook::HostRename.new
    hook.log_level = Logger::WARN
    hook.database_path = File.dirname(__FILE__) + '/test.db'
    hook.initialize_database
    File.unlink hook.database_path
  end

  # Try all of the supported hook actions
  def test_hook_actions
    
    hook = ForemanHook::HostRename.new(config: {
       'foreman_host' => 'dummy',
       'foreman_user' => 'dummy',
       'foreman_password' => 'dummy',
       'database_path' => File.expand_path(File.dirname(__FILE__) + '/test.db'),
       'rename_hook_command' => File.dirname(__FILE__) + '/hook-script.sh',
       'log_level' => 'debug',
    })

    # This would try to connect to Foreman, so make it a NOOP
    def hook.sync_host_table ; return ; end

    # Create a host
    fire(hook, 'create', { 'host' => { 'id' => '999999', 'name' => 'foo.example.com'}})
    db = hook.instance_variable_get(:@db)
    assert_equal(['foo.example.com'], db.get_first_row('select name from host where id = 999999'))

    # Update the host, without renaming it
    fire(hook, 'update', { 'host' => { 'id' => '999999', 'name' => 'foo.example.com'}})
    db = hook.instance_variable_get(:@db)
    assert_equal(['foo.example.com'], db.get_first_row('select name from host where id = 999999'))
    refute(hook.rename?, 'falsely detected that a rename occurred')

    # Rename the host
    fire(hook, 'update', { 'host' => { 'id' => '999999', 'name' => 'bar.example.com'}})
    db = hook.instance_variable_get(:@db)
    assert_equal(['bar.example.com'], db.get_first_row('select name from host where id = 999999'))
    assert(hook.rename?, 'failed to detect that a rename occurred')
    hook.execute_rename_action

    # Destroy the host
    fire(hook, 'destroy', { 'host' => { 'id' => '999999', 'name' => 'bar.example.com'}})
    db = hook.instance_variable_get(:@db)
    assert_equal(nil, db.get_first_row('select name from host where id = 999999'))

    # Cleanup
    File.unlink hook.database_path
  end

  private

  def fire(hook,action,hostobj)
    old_stdin = $stdin
    old_argv0 = ARGV[0]
    ARGV[0] = action
    $stdin = StringIO.new(hostobj.to_json)
    hook.run
    $stdin = old_stdin
    ARGV[0] = old_argv0
  end
end
