# This will simply do chmod g+w on all dir
# See task :setup
set :group_writable, true

after "deploy:setup", :roles => :web do
  # If :deploy_to is something like /var/www then deploy:setup created
  # directories with sudo and we need to fix it
  sudo "chown -R #{apache_user}:#{apache_group} #{deploy_to}"
  run "mkdir #{shared_path}/var"
end

after "deploy:update", :roles => :web do
  capez.cache.clear
  capez.autoloads.generate
  capez.var.fix_permissions
end

before "deploy", :roles => :web do
  deploy.web.disable
end

after "deploy", :roles => :web do
  deploy.web.enable
end

namespace :deploy do

  desc <<-DESC
    Finalize the update by creating symlink var -> shared/var
  DESC
  task :finalize_update do
    capez.var.link
  end

  namespace :web do
    desc <<-DESC
      Puts a html file somewhere in the documentroot
      This file is displayed by a RewriteRule if it exists
    DESC
    task :disable do
    end

    desc <<-DESC
      Remove the html file so that the application is reachable
    DESC
    task :enable do
    end
  end
  # End of namespace :deploy:web

end

namespace :capez do

  # TODO : cache management must be aware of cluster setup
  namespace :cache do
    desc <<-DESC
      Clear caches the way it is configured in ezpublish.rb
    DESC
    task :clear, :roles => :web  do
      on_rollback do
        clear
      end
      cache_list.each { |cache_tag| capture "cd #{current_path} && php bin/php/ezcache.php --clear-tag=#{cache_tag}" }
    end
  end

  namespace :var do
    desc <<-DESC
      Link .../shared/var into ../releases/[latest_release]/var
    DESC
    task :link, :roles => :web do
      run "ln -s #{shared_path}/var #{latest_release}/var"
    end

    desc <<-DESC
      Set the right permissions in var/
    DESC
    task :fix_permissions do
      sudo "chgrp -R #{apache_group} #{shared_path}/var"
      sudo "chgrp -h #{apache_group} #{current_path}/var"
      sudo "chmod -R g+w #{shared_path}/var"
    end

  end
  # End of namespace :capez:var

  # TODO : cache management must be aware of cluster setup  namespace :autoloads do
  namespace :autoloads do
    desc <<-DESC
      Generates autoloads (extensions and kernel overrides)
    DESC
    task :generate do
      on_rollback do
        generate
      end
      autoload_list.each { |autoload| capture "cd #{current_path} && php bin/php/ezpgenerateautoloads.php --#{autoload}" }
      # does not work since the script does not know how to deal with multiple arguments...
      #capture "cd #{current_path} && php bin/php/ezpgenerateautoloads.php --#{autoload_list.join( " --" )}"
    end
  end
  # End of namespace :capez:autoloads
end
