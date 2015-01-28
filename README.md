foreman_hooks-host_rename
===================

This hook is designed to extend the Foreman Hooks mechanism to detect when a host 
has been renamed and fire a custom 'rename' hook.

Requirements
============

This hook has only been tested in the following environment:

 * CentOS 6.5
 * Ruby 1.9.3 installed via the SCL mechanism

Installation
============

  1. Install the gem as root, using the Ruby 1.9 install location:
  
        sudo scl enable ruby193 'gem install foreman_hooks-host_rename'
  
  2. Create a configuration file in /etc/foreman_hooks-host_rename/settings.yaml.
     See the 'Configuration' section for details.
  
  3. Run 'sudo foreman_hooks-host_rename --install' to register the hook with
     Foreman.
  
  4. Restart Apache via 'sudo service httpd restart'

Configuration
=============

The configuration file is stored in conf/settings.yaml. Here are the variables:

foreman_host        

  The FQDN of the host that runs Foreman

foreman_user, foreman_password
  
  The user account to login to Foreman with

rename_hook_command

  The command to run after a host is renamed. A JSON object will be passed in via STDIN, and two parameters will be set in ARGV:
    1. the old hostname, as a FQDN
    2. the new hostname, as a FQDN

For an example, see conf/settings.yaml.EXAMPLE

Uninstallation
==============

To remove the hook, perform the following steps:

1. Run 'sudo foreman_hooks-host_rename --uninstall' to unregister the hook with
   Foreman.

2. Restart Apache via 'sudo service httpd restart'

Bugs
====

 * Some configuration options are undocumented.
 * The database and logs are stored in /var/tmp by default.
   
Copyright
=========

    Copyright 2015 Bronto Software, Inc.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
        http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
