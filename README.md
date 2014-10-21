foreman_hook-host_rename
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

1. Download the software to a directory on your Foreman server, such as /opt
1. Create the configuration file in conf/settings.yaml. See the 'Configuration' section for details.
1. Run 'sudo rake install' to install the hook.
1. Restart Apache via 'sudo service httpd restart'

Configuration
=============

The configuration file is stored in conf/settings.yaml. Here are the variables:

foreman_host        

  The FQDN of the host that runs Foreman

foreman_user, foreman_password
  
  The user account to login to Foreman with

rename_hook_command

  The command to run after a host is renamed. Two variables will be passed into the
  command via ARGV: 
    1. the old hostname, as a FQDN
    2. the new hostname, as a FQDN

For an example, see conf/settings.yaml.EXAMPLE


Bugs
====

 * The 'rake install' task is incomplete and does not work.
   
Copyright
=========

Copyright (c) 2014 Bronto Software Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.