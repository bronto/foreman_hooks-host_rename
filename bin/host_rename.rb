#!/usr/bin/env ruby
#
# Foreman hook that detects when a host has been renamed and runs a 'rename' hook
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

require 'bundler/setup'
require 'json'
require 'logger'
require 'kwalify'
require 'sqlite3'
require 'rest_client'
require 'pp'
require 'yaml'

# Given a nested hash, convert all keys from String to Symbol type
# Based on http://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
#
def symbolize(obj)
  return obj.inject({}){|memo,(k,v)| memo[k.to_sym] =  symbolize(v); memo} if obj.is_a? Hash
  return obj.inject([]){|memo,v    | memo           << symbolize(v); memo} if obj.is_a? Array
  return obj
end

# Parse the configuration file
def parse_config
  prefix = File.realpath(File.dirname(__FILE__) + '/..')
  confdir = File.realpath(File.dirname(__FILE__) + '/../conf')
  conffile = "#{confdir}/settings.yaml"
  raise "Configuration file #{conffile} does not exist" unless File.exist? conffile

  # Parse the configuration file
  @config = {
      database_path: prefix + '/db/foreman_hook_rename.db',
      log_level: 'warn'
  }.merge(symbolize(YAML.load(File.read(conffile))))

  # Validate the schema
  document = Kwalify::Yaml.load_file(conffile)
  schema = Kwalify::Yaml.load_file("#{confdir}/schema.yaml")
  validator = Kwalify::Validator.new(schema)
  errors = validator.validate(document)
  if errors && !errors.empty?
    puts "WARNING: The following errors were found in #{conffile}:"
    for e in errors
      puts "[#{e.path}] #{e.message}"
    end
    raise "Errors in the configuration file"
  end
end

# Given an absolute [+path+] within the Foreman API, return the full URI
def foreman_api(path)
  raise ArgumentError, 'path must start with a /' unless path =~ /^\//
  ['https://', @config[:foreman_user], ':', @config[:foreman_password], '@',
   @config[:foreman_host], '/api/v2', path].join('')
end

# Initialize an empty database
def initialize_database
  @db = SQLite3::Database.new @config[:database_path]
  begin
    rows = @db.execute <<-SQL
        create table host (
          id INT,
          name varchar(254)
        );
    SQL

    # Get all the host IDs and FQDNs and populate the host table
    uri = foreman_api('/hosts?per_page=9999999')
    debug "Loading hosts from #{uri}"
    json = RestClient.get uri
    debug "Got JSON: #{json}"
    JSON.parse(json)['results'].each do |rec|
      @db.execute "insert into host (id,name) values ( ?, ? )",
                 rec['id'], rec['name']
    end
  rescue
    File.unlink @config[:database_path]
    raise
  end
end

# Open a database connection. If the database does not exist, initialize it.
def open_database
  if File.exist? @config[:database_path]
    @db = SQLite3::Database.new @config[:database_path]
  else
    initialize_database
  end
end

# Update the database based on the foreman_hook
def execute_hook_action
  @rename = false
  name = @rec['host']['name']
  id = @rec['host']['id']

  case @action
  when 'create'
    sql = "insert into host (id, name) values (?, ?)"
    params = [id, name]
  when 'update'
    # Check if we are renaming the host
    @old_name = @db.get_first_row('select name from host where id = ?', id)[0]
    @rename = @old_name != name
    debug "checking for a rename: old=#{@old_name} new=#{name} rename?=#{@rename}"

    sql = 'update host set name = ? where id = ?'
    params = [name, id]
  when 'destroy'
    sql = 'delete from host where id = ?'
    params = [id]
  else
    raise ArgumentError, "unsupported action: #{ARGV[0]}"
  end
  debug "updating database; id=#{id} name=#{name} sql=#{sql}"
  stm = @db.prepare sql
  stm.bind_params *params
  stm.execute
end

# Check if the host has been renamed
# @return true, if the host has been renamed
def rename?
  @rename
end

def execute_rename_action
  cmd = @config[:rename_hook_command] + ' ' + @old_name + ' ' + @rec['host']['name']
  debug "Running the rename hook action: #{cmd}"
  rc = system cmd
  warn 'The rename hook returned a non-zero status code' unless rc
end

def parse_hook_data
  @action = ARGV[0]   # one of: create, update, destroy
  @rec = JSON.parse STDIN.read
  debug "action=#{@action} rec=#{@rec.inspect}"
end

def open_logfile
  @log = Logger.new(STDERR)
  case @config[:log_level]
  when 'debug'
    @log.level = Logger::DEBUG
  when 'warn'
    @log.level = Logger::WARN
  when 'info'
    @log.level = Logger::INFO
  else
    raise 'Unsupported log_level'
  end
end

# Convenience methods for writing to the logfile
def debug(message)    ; @log.debug(message)   ; end
def notice(message)   ; @log.notice(message)  ; end
def warn(message)  ; @log.warn(message) ; end

#
# MAIN()
#
if __FILE__ == $PROGRAM_NAME
  parse_config
  open_logfile
  open_database
  parse_hook_data
  execute_hook_action
  execute_rename_action if rename?
  exit 0
end
