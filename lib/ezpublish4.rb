puts "Running AlCapON for eZ Publish 4"

set :ezp_legacy, ""

after "deploy:finalize_update" do
  if fetch( :shared_children_group, false )
    shared_children.map { |d| run( "chgrp -R #{shared_children_group} #{shared_path}/#{d.split('/').last}") }
  end
  capez.var.init_release
  capez.var.link
  capez.settings.deploy
  capez.autoloads.generate
  #capez.cache.clear
end

namespace :capez do

  namespace :cache do
    desc <<-DESC
      Clear caches the way it is configured in ezpublish.rb
    DESC
    # Caches are just cleared for the primary server
    # Multiple server platform are supposed to use a cluster configuration (eZDFS/eZDBFS)
    # and cache management is done via expiry.php which is managed by the cluster API
    task :clear, :roles => :web, :only => { :primary => true } do
      puts( "\n--> Clearing caches #{'with --purge'.red if cache_purge}" )
      cache_list.each { |cache_tag|
        print_dotted( "#{cache_tag}" )
        capture "cd #{current_path}/#{ezp_legacy_path} && sudo -u #{webserver_user} php bin/php/ezcache.php --clear-tag=#{cache_tag}#{' --purge' if cache_purge}"
        puts( " OK".green )
      }
    end
  end

end
