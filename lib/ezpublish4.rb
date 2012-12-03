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