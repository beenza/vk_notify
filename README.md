Synopsis
========
simple command line utility for sending
a message to all application's users

Usage
-----
    vk_notify.rb [OPTIONS]
      
      --help, -h:
        this help

      --users, -u:
        users file

      --message, -m:
        message to send

      --app, -a:
        app name

Config
------
configuration lives in `~/.vk_apps`
it's a yaml file with following structure
    
    app_name:
      api_id: 123
      api_secret: foo

Author
------
Viktor Kotseruba <barbuza@me.com>

Copyright
---------
Copyright (c) 2010 Beenza Games
