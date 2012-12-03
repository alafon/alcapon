puts "Running AlCapON for eZ Publish 5"

set :ezp_legacy, "ezpublish_legacy"
set :ezp_app, "ezpublish"

after "deploy:finalize_update" do
  if fetch( :shared_children_group, false )
    shared_children.map { |d| run( "chgrp -R #{shared_children_group} #{shared_path}/#{d.split('/').last}") }
  end
  capez.var.init_release
  capez.var.link
  capez.settings.deploy
  capez.autoloads.generate
  capez.assets.install
end

namespace :capez do

  namespace :assets do

    task :install do

      run( "php ezpublish/console assets:install --symlink #{fetch('ezp5_assets_path','web')}", :as => webserver_user )
      run( "php ezpublish/console ezpublish:legacy:assets_install --symlink #{fetch('ezp5_assets_path','web')}", :as => webserver_user )

    end

  end

end