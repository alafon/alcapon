# AlCapON : Enable Capistrano for your eZ Publish installations

AlCapON is a simple recipe for Capistrano, the well-known deployment toolbox. It helps you dealing with simple task such as pushing your code to your webserver(s), clearing cache, etc.

IMPORTANT: this package is currently under development, please consider testing it on a preproduction environment before going further. Please also read the "Known bugs" section carefully.

## Features

* Source code deployment
* Remote database backup
* Local database import
* Storage folders sync. (remote => local only)
* Cache commands
* Autoloads generation

## Capistrano requirements

Even if the gemspec says that it requires capistrano >= 2.12, it might be
compatible with older version. If you've successfully used it on such versions
please fell free to give us some feedback.

## Installation

* Install Capistrano : see online documentation [here](https://github.com/capistrano/capistrano/wiki/2.x-Getting-Started)
* Install the alcapon gem : `gem install alcapon`

## Setting it up

* From /path/to/ezpublish, run `capezit .`. It creates :
	* at the eZ Publish root : a `Capfile` (know the makefile rakefile ? this one has the same purpose)
	* in extension/alcapon sample files you will need to edit later
* Server related configuration : modify config/deploy.rb to match your server configuration
	* if you want to disable the multistage feature (enabled by default), then comment the related lines at the top of config/deploy.rb
* eZ Publish related configuration :
	* modifiy config/ezpublish.rb to match your website configuration (such as db configuration)
	* if multistage is enabled : run `cap multistage:prepare`. It creates sample files in config/deploy/ for your environment overrides
* Make sure that the 'user' in config/deploy.rb has sudo rights so that he can create the required directories
* Run `cap deploy:setup` to create the needed directories
* Run `cap deploy:check` to check if your servers match the requirements
* Install missing/required stuff
* Run `cap deploy` and pray :)

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

## Contributing to AlCapON

Pretty simple :

* fork this repo on github
* clone your own fork in /somewhere/alcapon
* hack your Capfile and replace

````
load Gem.find_files('capez.rb').last.to_s
````
by

````
load '/somewhere/alcapon/lib/capez.rb'
````
* this way you can test what you do without building the gem everytime
* create a branch for each of your pull request (I may ask you to rebase your code)
* send me a pull request

## Contributors
Be the first !