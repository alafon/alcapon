# AlCapON : Enable Capistrano for your eZ Publish installations

Deploy your eZ Publish website on multiple servers

IMPORTANT: this package is currently under development, please consider testing it on a preproduction environment.

## Features

* Deployment
* Remote database backup and retrievment
* Remote database local import
* Remote cache related operations
* Autoload generation

## Capistrano requirements

Even if the gemspec says that it requires capistrano >= 2.12, it might be
compatible with older version. If you've successfully used it on such versions
please fell free to give some feedback.

## Installation

* From /path/to/ezpublish, run "capezit ."
* Server related configuration : modify config/deploy.rb to match your server configuration
* eZ Publish related configuration : modifiy config/ezpublish.rb to match your website configuration (such as db configuration)
* Make sure that the 'user' in config/deploy.rb has sudo rights so that he can create the required directories
* Run `cap deploy:setup` to create the needed directories
* Run `cap deploy:check` to check if your servers match the requirements)
* Install missing/required stuff
* Run `cap deploy`

## Dealing with the multistage plugin for capistrano

TODO

## Note regarding dependencies

The `deploy:check` task checks that the following are installed :
* PHP-CLI
* PHP >= 5.2.14
* Curl PHP extension

However, it does not check the followings requirements :
* eZ Components installation
* PHP
* Apache2/Nginx configuration (and required modules activation)

## Known bugs

* Having the var directory being a symlink to somewhere else seems to prevent the cache from working properly, see http://pwet.fr/blog/symlink_to_the_ez_publish_var_directory_a_good_idea