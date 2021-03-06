#
# Foreman hook that detects when a host has been renamed and runs a 'rename' hook
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

module ForemanHook
  class HostRename
    require 'fileutils'
    require 'json'
    require 'logger'
    require 'kwalify'
    require 'sqlite3'
    require 'rest_client'
    require 'pp'
    require 'yaml'
    
    attr_accessor :database_path

    # Given a nested hash, convert all keys from String to Symbol type
    # Based on http://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
    #
    def symbolize(obj)
      return obj.inject({}){|memo,(k,v)| memo[k.to_sym] =  symbolize(v); memo} if obj.is_a? Hash
      return obj.inject([]){|memo,v    | memo           << symbolize(v); memo} if obj.is_a? Array
      return obj
    end
    
    # Parse the configuration file
    def parse_config(conffile = nil)
      conffile ||= Dir.glob([
	  "/etc/foreman_hooks-host_rename/settings.yaml",
	  "#{confdir}/settings.yaml"])[0]
      raise "Could not locate the configuration file" if conffile.nil?
    
      # Parse the configuration file
      config = {
          hook_user: 'foreman',
          database_path: '/var/tmp/foreman_hooks-host_rename.db',
          log_path: '/var/tmp/foreman_hooks-host_rename.log',
          log_level: 'warn',
          rename_hook_command: '/bin/true',
      }.merge(symbolize(YAML.load(File.read(conffile))))
      config.each do |k,v|
        instance_variable_set("@#{k}",v)
      end
    
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
    
      check_script @rename_hook_command
    end
    
    # Do additional sanity checking on the database path
    def validate_database
      db = @database_path
      raise "bad mode of #{db}" unless File.world_readable?(db).nil?
    end

    # Do additional sanity checking on a hook script
    def check_script(path)
      binary=path.split(' ')[0]
      raise "#{path} does not exist" unless File.exist? binary
      raise "#{path} is not executable" unless File.executable? binary
      path
    end
    
    # Given an absolute [+path+] within the Foreman API, return the full URI
    def foreman_uri(path)
      raise ArgumentError, 'path must start with a /' unless path =~ /^\//
      ['https://', @foreman_user, ':', @foreman_password, '@',
       @foreman_host, '/api/v2', path].join('')
    end
    
    # Get all the host IDs and FQDNs and populate the host table
    def sync_host_table
      uri = foreman_uri('/hosts?per_page=9999999')
      debug "Loading hosts from #{uri}"
      json = RestClient.get uri
      debug "Got JSON: #{json}"
      JSON.parse(json)['results'].each do |rec|
        @db.execute "insert into host (id,name) values ( ?, ? )",
                   rec['id'], rec['name']
      end
    end

    # Initialize an empty database
    def initialize_database
      @db = SQLite3::Database.new @database_path
      File.chmod 0600, @database_path
      begin
        @db.execute 'drop table if exists host;'
        @db.execute <<-SQL
            create table host (
              id INT,
              name varchar(254)
            );
        SQL
        sync_host_table
      rescue
        File.unlink @database_path
        raise
      end
    end
    
    # Open a database connection. If the database does not exist, initialize it.
    def open_database
      if File.exist? @database_path
        validate_database
        @db = SQLite3::Database.new @database_path
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
        @old_name = @db.get_first_row('select name from host where id = ?', id)
        @old_name = @old_name[0] unless @old_name.nil?
        if @old_name.nil?
          warn 'received an update for a non-existent host'
        else
          @rename = @old_name != name
        end
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
      raise 'old_name is nil' if @old_name.nil? 
      raise 'new_name is nil' if @rec['host']['name'].nil?
      cmd = @rename_hook_command + ' ' + @old_name + ' ' + @rec['host']['name']
      debug "Running the rename hook action: #{cmd}"
      open("| #{ cmd } >> #{ @log_path } 2>&1", 'w+') do |subprocess|
        subprocess.write @rec.to_json
      end
      rc = $?.exitstatus
      warn "Hook exited with status #{rc}" if rc != 0
    end
    
    def parse_hook_data
      @action = ARGV[0]   # one of: create, update, destroy
      @rec = JSON.parse $stdin.read
      debug "action=#{@action} rec=#{@rec.inspect}"
    end
    
    def log_level=(level)
      @log_level = level
      @log.level = level
    end

    def open_logfile
      @log = Logger.new(@log_path, 10, 1024000)
      case @log_level
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
    def warn(message)     ; @log.warn(message)    ; end
    
    def initialize(opts = {})
      if opts.has_key? :config
        f = Tempfile.new('hook-settings')
        f.write(opts[:config].to_yaml)
        f.close
        parse_config(f.path)
      else
        parse_config
      end
    end

    def run
      open_logfile
      begin
        open_database
        parse_hook_data
        execute_hook_action
        execute_rename_action if rename?
      rescue Exception => e  
        @log.error e.message  
        @log.error e.backtrace.to_yaml
      end
    end

    def install(hookdir = nil)
      hookdir ||= '/usr/share/foreman/config/hooks/host/managed'
      raise "hook directory not found" unless File.exist? hookdir
      %w(create update destroy).each do |event|
        path = "#{hookdir}/#{event}"
        raise "path not found: #{path}" unless File.exist? path
        hook = "#{path}/99_host_rename"
        next if File.exist? hook
        f = File.open(hook, 'w')
        f.puts '#!/bin/sh'
        f.puts 'exec scl enable ruby193 "/usr/bin/foreman_hooks-host_rename $*"'
        f.close
        File.chmod 0755, hook
      end
      sysconfdir = '/etc/foreman_hooks-host_rename'
      Dir.mkdir sysconfdir unless File.exist? sysconfdir
      puts 'The hook has been installed. Please restart Apache to activate the hook.'
    end

    def uninstall(hookdir = nil)
      hookdir ||= '/usr/share/foreman/config/hooks/host/managed'
      %w(create update destroy).each do |event|
        hook = "#{hookdir}/#{event}/99_host_rename"
        #puts "removing #{hook}.."
        File.unlink hook if File.exist? hook
      end
      puts 'The hook has been uninstalled. Please restart Apache to deactivate the hook.'
    end

    private
  
    def prefix
      @prefix ||= File.realpath(File.dirname(__FILE__) + '/../../')
    end

    def confdir
      @confdir ||= "#{prefix}/conf"
    end
  end
end
