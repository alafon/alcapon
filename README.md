# AlCapON : Enable Capistrano for your eZ Publish installations

Deploy your eZ Publish website on multiple servers

IMPORTANT: this package is currently under development, please consider testing it on a preproduction environment.

## Features

* Source code deployment
* Remote database backup and retrievment
* Local import of your remote database backups
* Remote cache operations
* Autoload generation
* Storage sync (remote => local only)

## Capistrano requirements

Even if the gemspec says that it requires capistrano >= 2.12, it might be
compatible with older version. If you've successfully used it on such versions
please fell free to give some feedback.

## Installation

* Install Capistrano : see online documentation [here]
* Install alcapon gem : `gem install alcapon`

## Setting it up

* From /path/to/ezpublish, run `capezit .`. It creates sample files you will need to edit in extension/alcapon
* Server related configuration : modify config/deploy.rb to match your server configuration
	* if you want to disable the multistage feature (enabled by default), then comment the related lines at the bottom of config/deploy.rb
* eZ Publish related configuration :
	* multistage disabled : modifiy config/ezpublish.rb to match your website configuration (such as db configuration)
	* multistage enabled : run `cap multistage:prepare`. It creates sample files in config/deploy/ for your environment overrides
* Make sure that the 'user' in config/deploy.rb has sudo rights so that he can create the required directories
* Run `cap deploy:setup` to create the needed directories
* Run `cap deploy:check` to check if your servers match the requirements
* Install missing/required stuff
* Run `cap deploy`

## Note regarding dependencies

The `deploy:check` task checks that the following are installed :
* PHP-CLI
* PHP >= 5.2.14
* Curl PHP extension

However, it does not check the followings requirements :
* eZ Components installation
* PHP
* Apache2/Nginx configuration (and required modules activation)

## Todo List

* Auto-update : as the gem is currently under development, it should be able to check if a new version is available and inform the user how to upgrade its current alcapon gem
* Database configuration could(/should ?) be on the remote(s) itself, in a yml file for instance

## Known bugs

* Having the var directory being a symlink to somewhere else seems to prevent the cache from working properly, see http://pwet.fr/blog/symlink_to_the_ez_publish_var_directory_a_good_idea