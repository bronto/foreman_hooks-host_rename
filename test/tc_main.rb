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

require 'minitest'
require 'minitest/autorun'
require 'tempfile'

class TestMain < MiniTest::Test
  require_relative '../bin/host_rename'

  # Wipe the database and reinitialize it
  def test_initialize_database
    parse_config
    @config[:log_level] = 'warn'
    open_logfile
    dbfile = @config[:database_path]
    refute dbfile.nil?
    File.unlink dbfile if File.exist? dbfile
    initialize_database
  end

  # Try all of the supported hook actions
  def test_hook_actions
    parse_config
    @config[:log_level] = 'warn'
    open_logfile
    open_database

    @db.execute 'delete from host where id = 999999'

    # Create a hook script
    hookfile = Tempfile.new('hook-script')
    @config[:rename_hook_command] = hookfile.path
    hookfile.write "#!/bin/sh -e
#echo renaming $1 to $2
test $1 = 'foo.example.com'
test $2 = 'bar.example.com'
exit 0
"
    hookfile.close

    File.chmod 0755, hookfile.path

    # Create a host
    @action = 'create'
    @rec = { 'host' => { 'id' => '999999', 'name' => 'foo.example.com'}}
    execute_hook_action
    assert_equal(['foo.example.com'], @db.get_first_row('select name from host where id = 999999'))

    # Update the host, without renaming it
    @action = 'update'
    execute_hook_action
    assert_equal(['foo.example.com'], @db.get_first_row('select name from host where id = 999999'))
    refute(rename?, 'falsely detected that a rename occurred')

    # Rename the host
    @action = 'update'
    @rec = { 'host' => { 'id' => '999999', 'name' => 'bar.example.com'}}
    execute_hook_action
    assert_equal(['bar.example.com'], @db.get_first_row('select name from host where id = 999999'))
    assert(rename?, 'failed to detect that a rename occurred')
    execute_rename_action

    # Destroy the host
    @action = 'destroy'
    execute_hook_action
    assert_equal(nil, @db.get_first_row('select name from host where id = 999999'))
  end
end