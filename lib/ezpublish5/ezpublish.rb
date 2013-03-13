namespace :ezpublish do

  namespace :cache do
    desc <<-DESC
      Clear caches the way it is configured in ezpublish.rb
    DESC
    # Caches are just cleared for the primary server
    # Multiple server platform are supposed to use a cluster configuration (eZDFS/eZDBFS)
    # and cache management is done via expiry.php which is managed by the cluster API
    # TODO : make it ezp5 aware
    task :clear, :roles => :web, :only => { :primary => true } do
      puts( "\n--> Clearing caches #{'with --purge'.red if cache_purge}" )
      cache_list.each { |cache_tag|
        print_dotted( "#{cache_tag}" )
        capture "cd #{current_path}/#{ezp_legacy_path} && sudo -u #{fetch(:php_user,user)} php bin/php/ezcache.php --clear-tag=#{cache_tag}#{' --purge' if cache_purge}"
        capez_puts_done
      }
    end
  end

  namespace :assets do
    desc <<-DESC
      Install assets (ezp5 only)
    DESC
    task :install do
      print_dotted( "\n--> Generating web assets in #{fetch('ezp5_assets_path','web')}" )
      capture( "cd #{latest_release} && sudo -u #{fetch(:php_user,user)} php ezpublish/console assets:install --symlink #{fetch('ezp5_assets_path','web')}" )
      capture( "cd #{latest_release} && sudo -u #{fetch(:php_user,user)} php ezpublish/console ezpublish:legacy:assets_install --symlink #{fetch('ezp5_assets_path','web')}" )
      capez_puts_done
    end
  end

  namespace :settings do
    desc <<-DESC
      Generate yml (ezp5) based on ini (ezp4)
    DESC
    task :configure do
      print_dotted( "\n--> Generating ezp5 configuration files from ezp4 ones" )
      if( fetch('ezp5_siteaccess_groupname',false) != false && fetch('ezp5_admin_siteaccess',false) != false )
        capture( "cd #{latest_release} && sudo -u #{fetch(:php_user,user)} php ezpublish/console ezpublish:configure --env=#{fetch('ezp5_env','prod')} #{ezp5_siteaccess_groupname} #{ezp5_admin_siteaccess}" )
      else
        abort( "Since version 0.4.3, you need to set ezp5_siteaccess_groupname & ezp5_admin_siteaccess".red )
      end
      capez_puts_done
    end

  end

end