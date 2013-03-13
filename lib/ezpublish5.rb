puts "Running AlCapON for eZ Publish 5"

set :ezp_legacy, "ezpublish_legacy"
set :ezp_app, "ezpublish"

load 'ezpublish5/deploy'
load 'ezpublish5/ezpublish'

after "deploy:finalize_update" do
  if fetch( :shared_children_group, false )
    shared_children.map { |d| run( "chgrp -R #{shared_children_group} #{shared_path}/#{d.split('/').last}") }
  end
  ezpublish.var.init_release
  ezpublish.var.link
  ezpublish.autoloads.generate
  ezpublish.settings.deploy
  ezpublish.assets.install
  if ( fetch( :ezp5_regenerate_config, false ) )
    ezpublish.settings.configure
  end
end

