load_paths.push File.expand_path('../', __FILE__)
load 'db.rb'

# This will simply do chmod g+w on all dir
# See task :setup
set :group_writable, true

after "deploy:setup", :roles => :web do
  try_sudo( "chown -R #{user} #{deploy_to}" )
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
    Finalize the update (symlink, autoloads, configuration changes)
  DESC
  task :finalize_update do
    capez.var.link
    capez.autoloads.generate
    capez.settings.replace
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

namespace :deploy do
  namespace :rollback do
    task :cleanup, :except => { :no_release => true } do
      run( "if [ `readlink #{current_path}` != #{current_release} ]; then #{sudo} rm -rf #{current_release}; fi" )
    end
  end
end


namespace :capez do

  namespace :settings do
    task :replace, :roles => :web do
      unless !(file_changes = get_file_changes) then
        file_changes.each { |filename,operations|
          puts "Processing file : #{filename}"
          target_filename = filename

          if operations.has_key?("rename")
            target_filename = operations['rename']
            puts "- renaming to : #{target_filename}"
            run( "if [ -f #{latest_release}/#{filename} ]; then cp #{latest_release}/#{filename} #{latest_release}/#{target_filename}; fi;" )
          end

          operations.each { |operation,value|
            case operation
              when 'rename'
              when 'replace'
                value.each { |search,replace|
                  puts "- replacing '#{search}' by '#{replace}'"
                  #search = search.gsub("/","\\/")
                  #replace = replace.gsub("/","\\/")
                  #run( "sed 's/#{search}/#{replace}/g' #{latest_release}/#{target_filename} > #{latest_release}/#{target_filename}.replaced" )
                }
              else
                puts "'#{operation}' operation is not supported"
            end
          }
        }
      else
        puts "No file changes needs to be applied. Please set :file_changes"
      end
    end

    def get_file_changes
      return fetch( :file_changes, false )
    end
  end

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
      try_sudo( "mkdir #{shared_path}/var" )
      try_sudo( "chmod g+w #{shared_path}/var" )
      try_sudo( "chgrp -R #{webserver_group} #{shared_path}/var" )

      try_sudo( "mkdir -p #{shared_path}/var/storage", :as => fetch( :webserver_user ) )
      siteaccess_list.each{ |siteaccess_identifier|
        try_sudo( "mkdir -p #{shared_path}/var/#{siteaccess_identifier}/storage", :as => fetch( :webserver_user ) )
      }

    end

    desc <<-DESC
      Link .../shared/var into ../releases/[latest_release]/var
    DESC
    task :link, :roles => :web do
      try_sudo( "mkdir #{latest_release}/var" )
      try_sudo( "chmod g+w #{latest_release}/var" )
      try_sudo( "chgrp -R #{webserver_group} #{latest_release}/var" )

      siteaccess_list.each{ |siteaccess_identifier|
        try_sudo( "mkdir #{latest_release}/var/#{siteaccess_identifier}", :as => fetch( :webserver_user ) )
      }

      try_sudo( "ln -s #{shared_path}/var/storage #{latest_release}/var/storage", :as => fetch( :webserver_user ) )
      siteaccess_list.each{ |siteaccess_identifier|
        try_sudo( "ln -s #{shared_path}/var/#{siteaccess_identifier}/storage #{latest_release}/var/#{siteaccess_identifier}/storage", :as => webserver_user )
      }
    end

    desc <<-DESC
      Sync your var directory with a remote one
    DESC
    task :sync_to_local, :roles => :web, :only => { :primary => true } do
      confirmation = Capistrano::CLI.ui.ask "You're about to sync your local var/ directory FROM a remote one (current stage = #{stage}). Are you sure (y/N) ?"
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

    desc <<-DESC
      Sync your a remote var folder with local datas
    DESC
    task :sync_to_remote, :roles => :web, :only => { :primary => true } do
      confirmation = Capistrano::CLI.ui.ask "You're about to sync your local var/ directory TO a remote one (current stage = #{stage}). Are you sure (y/N) ?"
      abort "Aborted" unless confirmation.downcase == 'y'

      shared_host = fetch( :shared_host, nil )
      abort "Please set 'shared_host'" if shared_host == nil

      # TODO : make it configurable
      exclude_string = ""
      exclude_paths = [ "/cache", "/log", "/*/cache", "/*/log", "/autoload" ]
      exclude_paths.each{ |item|
        exclude_string << "--exclude '#{item}' "
      }

      try_sudo( "chown -R #{user}:#{webserver_user} #{shared_path}/var/*" )
      run_locally( "rsync -az #{exclude_string} var/* #{user}@#{shared_host}:#{shared_path}/var/ " )
      try_sudo( "chown -R #{webserver_user} #{shared_path}/var/*" )
      try_sudo( "chmod -R ug+rwx #{shared_path}/var/*" )
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
