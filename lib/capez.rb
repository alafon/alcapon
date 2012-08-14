load_paths.push File.expand_path('../', __FILE__)
load 'db.rb'

# This will simply do chmod g+w on all dir
# See task :setup
set :group_writable, true

after "deploy:setup", :roles => :web do
  capez.var.init_shared
end

after "deploy:update", :roles => :web do
  # We don't need to clear the cache anymore but a warmup might be needed
  #capez.cache.clear
end

before "deploy", :roles => :web do
  capez.dev.local_check
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
    capez.autoloads.generate
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

  namespace :cache do
    desc <<-DESC
      Clear caches the way it is configured in ezpublish.rb
    DESC
    # Caches are just cleared for the primary server
    # Multiple server platform are supposed to use a cluster configuration (eZDFS/eZDBFS)
    # and cache management is done via expiry.php which is managed by the cluster API
    task :clear, :roles => :web, :only => { :primary => true } do
      on_rollback do
        clear
      end
      cache_list.each { |cache_tag| capture "cd #{current_path} && sudo -u #{webserver_user} php bin/php/ezcache.php --clear-tag=#{cache_tag}#{' --purge' if cache_purge}" }
    end
  end

  namespace :var do
    desc <<-DESC
      Creates the needed folder within your remote(s) var directories
    DESC
    task :init_shared, :roles => :web do
      run( "mkdir -p #{shared_path}/var/storage" )
      siteaccess_list.each{ |siteaccess_identifier|
        run( "mkdir -p #{shared_path}/var/#{siteaccess_identifier}/storage" )
      }

      fix_permissions( "#{shared_path}/var", webserver_user, webserver_group )
    end

    desc <<-DESC
      Link .../shared/var into ../releases/[latest_release]/var
    DESC
    task :link, :roles => :web do
      run( "mkdir #{latest_release}/var" )
      siteaccess_list.each{ |siteaccess_identifier|
        run( "mkdir #{latest_release}/var/#{siteaccess_identifier}" )
      }

      fix_permissions( "#{latest_release}/var", webserver_user, webserver_group )

      try_sudo( "ln -s #{shared_path}/var/storage #{latest_release}/var/storage", :as => webserver_user )
      siteaccess_list.each{ |siteaccess_identifier|
        try_sudo( "ln -s #{shared_path}/var/#{siteaccess_identifier}/storage #{latest_release}/var/#{siteaccess_identifier}/storage", :as => webserver_user )
      }
    end

    desc <<-DESC
      Sync your var directory with a remote one
    DESC
    task :sync, :roles => :web, :only => { :primary => true } do
      confirmation = Capistrano::CLI.ui.ask "You're about to sync your local var/ directory with a remote one (current stage = #{stage}). Are you sure (y/N) ?"
      abort "Aborted" unless confirmation.downcase == 'y'

      shared_host = fetch( :shared_host, nil )
      abort "Please set 'shared_host'" if shared_host == nil

      # TODO : make it configurable
      exclude_string = ""
      exclude_paths = [ "/cache", "/log", "/*/cache", "/*/log", "/autoload" ]
      exclude_paths.each{ |item|
        exclude_string << "--exclude '#{item}' "
      }

      run_locally( "rsync -az #{exclude_string} #{user}@#{shared_host}:#{shared_path}/var/* var/" )
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
      autoload_list.each { |autoload|
        capture( "cd #{latest_release} && sudo -u #{webserver_user} php bin/php/ezpgenerateautoloads.php --#{autoload}" )
      }
    end
  end
  # End of namespace :capez:autoloads

  # Should be transformed in a simple function (not aimed to be called as a Cap task...)
  namespace :dev do
    desc <<-DESC
      Checks if there are local changes or not (only with Git)
      Considers that your main git repo is at the top of your eZ Publish install
      If changes are detected, then ask the user to continue or not
    DESC
    task :local_check do
      if "#{scm}" != "git" then
        abort "Feature only available with git"
      end

      ezroot_path = fetch( :ezpublish_path, false )
      abort "Please set a correct path to your eZ Publish root (:ezpublish_path) or add 'set :ezpublish_path, File.expand_path( File.dirname( __FILE__ ) )' in your Capfile" unless ezroot_path != false and File.exists?(ezroot_path)

      git_status = git_status_result( ezroot_path )

      ask_to_abort = false
      puts "Checking your local git..."
      if git_status['has_local_changes']
        ask_to_abort = true
        puts "You have local changes"
      end
      if git_status['has_new_files']
        ask_to_abort = true
        puts "You have new files"
      end

      if ask_to_abort
        user_abort = Capistrano::CLI.ui.ask "Abort ? y/n (n)"
        abort "Deployment aborted to commit/add local changes" unless user_abort == "n" or user_abort == ""
      end

      if git_status['tracked_branch_status'] == 'ahead'
        puts "You have #{git_status['tracked_branch_commits']} commits that need to be pushed"
        push_before = Capistrano::CLI.ui.ask "Push them before deployment ? y/n (y)"
        if push_before == "" or push_before == "y"
          system "git push"
        end
      end
    end
  end

  def git_status_result(path)
    result = Hash.new
    result['has_local_changes'] = false
    result['has_new_files'] = false
    result['tracked_branch'] = nil
    result['tracked_branch_status'] = nil
    result['tracked_branch_commits'] = 0
    cmd_result = `cd #{path} && git status 2> /dev/null`
    result['raw_result'] = cmd_result
    cmd_result_array = cmd_result.split( /\n/ );
    cmd_result_array.each { |value|
      case value
        when /# Changes not staged for commit:/
          result['has_local_changes'] = true
        when /# Untracked files:/
          result['has_new_files'] = true
        when /# On branch (.*)$/
          result['branch'] = $1
        when /# Your branch is (.*) of '(.*)' by (.*) commits?/
          result['tracked_branch_status'] = $1
          result['tracked_branch'] = $2
          result['tracked_branch_commits'] = $3
      end
      }
      return result
  end

  def fix_permissions(path,userid,groupid)
      # If admin_runner is not null then make sure that the command is not run with -u admin_runner
      if fetch( :admin_runner, nil ) != nil
        run( "sudo chown -R #{userid}:#{groupid} #{path}" )
      else
        try_sudo( "chown -R #{userid}:#{groupid} #{path}" )
      end
  end

end
