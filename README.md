# AlCapON : Enable Capistrano for your eZ Publish installations

AlCapON is a simple recipe for Capistrano, the well-known deployment toolbox.
It helps you dealing with simple task such as pushing your code to your
webserver(s), clearing cache, etc.

IMPORTANT: this package is currently under development, please consider testing
it on a preproduction environment before going further. Please also do read the
"Known bugs" section carefully.

## Changelog

### 0.4.x

 - added eZ Publish 5.x support for ezpublish_legacy. This means that version
   of eZ Publish must be known by alcapon. You can either set ezpublish_version
   (accepted values are 4 or 5) in your Capfile or add `-S ezpublish_version=4`
   or `-S ezpublish_version=5` after your command line call, like this :
   cap production deploy -S ezpublish_version=5

### 0.3.x

 - added the possibility to trigger rename and in-file replace operations
   during the deployment (see the generated file
   config/deploy/production.rb after running the capezit command)

 - major changes in permissions management for the var/ folders. Previous
   versions tried to manage different cases by using sudo commands but I'm
   convinced that it is not the right place to do that. Permissions have to be
   handled by sysadmin, not Capistrano.
   This will be improved, maybe simplified again, in next versions.
   In consequence, you might experienced some issues, but please, let me know.

 - usage of siteaccess_list in ezpublish.rb is deprecated as of 0.3.0. Please
   use storage_directories instead (see issue #2)

## Requirements, installation & co

Please see [alafon.github.com/alcapon](http://alafon.github.com/alcapon)
