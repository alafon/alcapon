# AlCapON : Enable Capistrano for your eZ Publish installations

==============

**DISCONTINUED** : with the *recent* move to Symfony Framework, AlCapOn is not required anymore to deploy eZ Publish websites.

We recommend to use Capistrano v3 together with capistrano libs like `capistrano/composer` and `capistrano/symfony`.

Placeholders formerly handled by AlCapOn can be managed in `ezpublish/config/parameters.yml.dist` with Incenteev which is included by default in Symfony. See https://github.com/Incenteev/ParameterHandler and use environment variable injection in your `config/xxxxxx.rb`.

If you still need to handle eZ Publish Legacy parameters, then just manage them in your parameters.yml and inject them from the symfony stack using https://doc.ez.no/display/EZP/Legacy+configuration+injection

Feel free to contact me at `alcapon` `at` `phasetwo.fr` if you need support.

==============

AlCapON is a simple recipe for Capistrano, the well-known deployment toolbox.
It helps you dealing with simple task such as pushing your code to your
webserver(s), clearing cache, etc.

IMPORTANT: this package is currently under development, please consider testing
it on a preproduction environment before going further. Please also do read the
"Known bugs" section carefully.

CAPISTRANO dependency : we recommand not to use Capistrano >= 2.15 which for some
reason broke something (see https://github.com/alafon/alcapon/issues/7 and https://github.com/alafon/capistrano/commit/e4f207b4b44e9fa5fa18ec4e85a7469d94570095)

AlCapON is not fully compatible with Capistrano 3.x, we are working on it and we recommand to stay on the 2.x branch.

In addition, Capistrano 2.x and Capistrano 3.x can be installed on the same machine so if you update Capistrano to 3.x (because you need for other projects), simply create a simlink in any of your local PATH, to your 2.x bin executable. Exemple on a Mac setup :

`/usr/local/bin/cap2 => /Library/Ruby/Gems/2.0.0/gems/capistrano-2.14.2/bin/cap`

## Changelog

### 0.4.x

 - pin net-ssh to 2.9.2 (net-ssh 3.x requires Ruby 2.x and we don't want that restriction)
 - removed in 0.4.15 : the 'ezpublish:var:link' task does not call `chown`
   anymore since we must not alter the permissions in shared ressources. They
   must be controlled by ezpublish ONLY
 - added in 0.4.1 : downloaded files are hashed so that they can be downloaded
   somewhere there's no eZ Publish installed
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
