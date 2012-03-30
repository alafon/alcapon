# AlCapOn : Enable Capistrano for your eZ Publish installations

Deploy your eZ Publish website on multiple servers

## Features

* Deployment
* Remote database backup
* Remote database retrievment and local import
* Remote cache related operations
* Autoload generation

## Installation

* Server related configuration : modify config/deploy.rb to match your server configuration
* eZ Publish related configuration : modifiy config/ezpublish.rb to match your website configuration (such as db configuration)
* Make sure that the 'user' in config/deploy.rb has sudo rights so that he can create the required directories
* Run `cap deploy:setup` to create the needed directories
* Run `cap deploy:check` to check if your servers match the requirements)
* Install missing/required stuff
* Run `cap deploy`

## Note regarding dependencies

The `deploy:check` task checks that the following are installed :
* PHP-CLI
* PHP >= 5.2.14
* Apache2 prepork & libapache2-mod-php5
* Curl PHP extension

However, it does not check the followings requirements :
* eZ Components installation
* PHP
* Apache2 configuration (and module activation)

## Known bugs

* Having the var directory being a symlink to somewhere else seems to prevent the cache from working properly