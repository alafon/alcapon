# This file contains eZ Publish adjustable variables depending on your custom setup

# Apache user and group, used to chmod directories just after deploy:setup
set :apache_user, user
set :apache_group, "www-data"

# If true, will always turn your webserver offline
# Requires a specific rewrite rule (see documentation)
set :always_turnoff, false

# Array taking all the values given by php bin/php/ezcache.php --list-tags
#
# If you want to clear all caches use :
# set :cache_list, "all"
set :cache_list, [ "template", "ini", "content" ]

# If true, adds '--purge' to the ezcache.php command
set :cache_purge, false

# Which autoloads to generate. By default, regenerates extensions and
# kernel-override autoloads
# Possible values : see bin/php/ezpgenerateautoloads.php --help
set :autoload_list, [ "extension", "kernel-override" ]

set :database_uname, "user"
set :database_passd, "password"
set :database_name, "db"

# Not implemented
set :ezpublish_separated_core, false
set :ezpublish_base, "community"
set :ezpublish_version, "2011.10"