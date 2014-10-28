#!/usr/bin/env ruby
#
# Copyright (c) 2014 Bronto Software Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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
