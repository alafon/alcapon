require 'colored'

load_paths.push File.expand_path('../', __FILE__)
load "utils"

if( fetch( :ezpublish_version, nil ) == nil )
  alcapon_message( "I am now able to manage versions 4 & 5 of eZ Publish but you
          have to set :ezpublish_version
          - in your Capfile like this : set :ezpublish_version, <ezpublish_version>
          - as a command line option : -S ezpublish_version=<ezpublish_version>
          where <ezpublish_version> can be either 4 or 5." )
  abort
else
  fetch(:ezpublish_version) == 4 || fetch(:ezpublish_version) == 5 || abort( "Version #{ezpublish_version} not supported".red )
  load "db"
  load "ezpublish#{ezpublish_version}"
end

# This will simply do chmod g+w on all dir
# See task :setup
set :group_writable, true

# triggered after all recipes have loaded
on :load do
  if( fetch( :siteaccess_list, nil ) != nil )
    abort "The usage of siteaccess_list in ezpublish.rb is deprecated as of 0.3.0.\nPlease use storage_directories instead".red
  end
end

before "deploy:setup" do
  print_dotted( "--> Creating default directories" )
end

after "deploy:setup", :roles => :web do
  puts( " OK".green )
  print_dotted( "--> Fixing permissions on deployment directory" )
  try_sudo( "chown -R #{user} #{deploy_to}" ) # if not code checkout cannot be done :/
  puts( " OK".green )
  capez.var.init_shared
end

before "deploy:update_code" do
  puts( "\n*** Building release ***" )
  puts( "Started at " + Time.now.utc.strftime("%H:%M:%S") )
  print_dotted( "--> Updating code", :sol => true )
end

after "deploy:update_code" do
  puts( "\n*** Release ready ***".green )
  puts( "Finished at " + Time.now.utc.strftime("%H:%M:%S") )
end

before "deploy:finalize_update" do
  puts( " OK".green )
  # Needed if you want to create extra shared directories under var/ with
  # set :shared_children, [ "var/something",
  #                         "var/something_else" ]
  # Note that :shared_children creates a folder within /shared which name is
  # the last path element (ie: something or something_else) => that's why
  # we cannot use it to create siteaccess' storage folder (var/siteaccess/storage)
  run( "mkdir -p #{latest_release}/#{ezp_legacy_path('var')}" )
end

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

before "deploy", :roles => :web do
  capez.dev.local_check
  deploy.web.disable
end

after "deploy", :roles => :web do
  deploy.web.enable
end

before "deploy:create_symlink" do
  print_dotted( "--> Going live (symlink)", :sol => true )
end

after "deploy:create_symlink" do
  puts( " OK".green )
end

# Default behavior overrides
namespace :deploy do

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

    def make_file_changes( options={} )

      default_options = { :locally => false }
      options = default_options.merge( options )

      puts( "\n--> File operations" )

      unless !(file_changes = get_file_changes) then

        path = options[:locally] ? "" : fetch( :latest_release )

        changes = 0
        renames = 0
        errors = []
        messages = []

        print_dotted( "execution", :eol_msg => (options[:locally] ? "local" : "distant" ), :eol => true, :max_length => 25 )
        print_dotted( "files count", :eol_msg => "#{file_changes.count}", :eol => true, :max_length => 25 )

        # process each files
        print( "progress " )
        file_changes.each { |filename,operations|

          print( "." )

          target_filename = filename
          renamed = false

          # rename operation is caught and executed at first
          if operations.has_key?("rename")
            if( target_filename != operations['rename'] )
              target_filename = operations['rename']
              cmd = "if [ -f #{path}/#{filename} ]; then cp #{path}/#{filename} #{path}/#{target_filename}; fi;"
              options[:locally] ? run_locally( "#{cmd}" ) : run( "#{cmd}" )
              renames += 1
            else
              target_filename = operations['rename']
              errors += ["target and original name are the same (#{target_filename})"]
            end
          end

          operations.each { |operation,value|
            case operation
              when 'rename'
              when 'replace'

                if( value.count > 0 && !dry_run)

                  # download file if necessary
                  if options[:locally]
                    tmp_filename = target_filename
                  else
                    tmp_filename = target_filename+".tmp"
                    get "#{path}/#{target_filename}", tmp_filename
                  end

                  text = File.read(tmp_filename)
                  value.each { |search,replace|
                    changes += 1
                    text = text.gsub( "#{search}", "#{replace}" )
                  }
                  File.open(tmp_filename, "w") {|file| file.write(text) }

                  # upload and remove temporary file
                  if !options[:locally]
                    run( "if [ -f #{target_filename} ]; then rm #{target_filename}; fi;" )
                    upload( tmp_filename, "#{path}/#{target_filename}" )
                    run_locally( "rm #{tmp_filename}" )
                  end
                end
              else
                errors += ( "operation '#{operation}' supported" )
            end
          }
        }
        puts " done".green

        # stats
        print_dotted( "files renamed", :eol_msg => "#{renames}", :eol => true, :max_length => 25 )
        print_dotted( "changes count", :eol_msg => "#{changes}", :eol => true, :max_length => 25 )
        print_dotted( "changes avg / file", :max_length => 25, :eol_msg => ( file_changes.count > 0 ? "#{changes/file_changes.count}" : "" ), :eol => true )
        messages.each { |msg| puts( "#{msg}") }
        puts( "errors : ".red ) unless errors.count == 0
        errors.each { |msg| puts( "- #{msg}".red ) }
      else
        puts( "No file changes needs to be applied. Please set :file_changes".blue )
      end
    end

    desc <<-DESC
      Makes some file level operations if needed (rename, replace)
    DESC
    task :deploy, :roles => :web do
      make_file_changes
    end

    desc <<-DESC
      [local] Makes some file level operations if needed (rename, replace)
    DESC
    task :deploy_locally, :roles => :web do
      make_file_changes( :locally => true )
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
      puts( "\n--> Clearing caches #{'with --purge'.red if cache_purge}" )
      cache_list.each { |cache_tag|
        print_dotted( "#{cache_tag}" )
        capture "cd #{current_path}/#{ezpublish_legacy} && sudo -u #{webserver_user} php bin/php/ezcache.php --clear-tag=#{cache_tag}#{' --purge' if cache_purge}"
        puts( " OK".green )
      }
    end
  end

  namespace :var do
    desc <<-DESC
      Creates the needed folder within your remote(s) var directories
    DESC
    task :init_shared, :roles => :web do
      puts( "--> Creating eZ Publish var directories" )
      print_dotted( "var " )
      run( "mkdir -p #{shared_path}/var" )
      puts( " OK".green )

      print_dotted( "var/storage" )
      run( "mkdir -p #{shared_path}/var/storage" )
      puts( " OK".green )

      storage_directories.each{ |sd|
        print_dotted( "var/#{sd}/storage" )
        run( "mkdir -p #{shared_path}/var/#{sd}/storage" )
        puts( " OK".green )
      }
      run( "chmod -R g+w #{shared_path}/var")
      run( "chown -R #{fetch(:webserver_group,:user)} #{shared_path}/var")
    end



    desc <<-DESC
      [internal] Creates release directories
    DESC
    task :init_release, :roles => :web do
      puts( "\n--> Release directories" )

      if( ezp5? )
        run( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{latest_release}/ezpublish/{cache,logs,config} web" )
        run( "chmod -R g+wx #{latest_release}/ezpublish/{cache,logs} web" )
      end

      # creates a storage dir for elements specified by :storage_directories
      storage_directories.each{ |sd|
        print_dotted( "var/#{sd}/storage" )
        run( "mkdir #{latest_release}/" + ezp_legacy_path( "var/#{sd}" ) )
        puts( " OK".green )
      }

      # makes sure the webserver can write into var/
      run( "chmod -R g+w #{latest_release}/" + ezp_legacy_path( "var" ) )
      run( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{latest_release}/" + ezp_legacy_path( "var" ) )
      # needed even if we just want to run 'bin/php/ezpgenerateautoloads.php' with --extension
      run( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{latest_release}/" + ezp_legacy_path( "autoload" ) )
    end

    desc <<-DESC
      Link .../shared/var into ../releases/[latest_release]/var
    DESC
    task :link, :roles => :web do
      puts( "\n--> Symlinks" )

      print_dotted( "var/storage" )
      run( "ln -s #{shared_path}/var/storage #{latest_release}/" + ezp_legacy_path( "var/storage" ) )
      puts( " OK".green )

      storage_directories.each{ |sd|
        print_dotted( "var/#{sd}/storage" )
        run( "ln -s #{shared_path}/var/#{sd}/storage #{latest_release}/" + ezp_legacy_path( "var/#{sd}/storage" ), :as => webserver_user )
        #run( "chmod -h g+w #{latest_release}/var/#{sd}/storage")
        puts( " OK".green )
      }

      run( "chmod -R g+w #{latest_release}/" + ezp_legacy_path( "var" ) )
      run( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{shared_path}/var")
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

      run_locally( "rsync -az #{exclude_string} #{user}@#{shared_host}:#{shared_path}/var/* " + ezp_legacy_path( "var/" ) )
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
      run_locally( "rsync -az #{exclude_string} #{ezp_legacy_path('var')}/* #{user}@#{shared_host}:#{shared_path}/var/ " )
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
      if autoload_list.count == 0
        print_dotted( "--> eZ Publish autoloads (disabled)", :sol => true )
        puts( " OK".green )
      else
        puts( "\n--> eZ Publish autoloads " )
        autoload_list.each { |autoload|
          print_dotted( "#{autoload}" )
          capture( "cd #{latest_release}/#{ezp_legacy_path} && sudo -u #{webserver_user} php bin/php/ezpgenerateautoloads.php --#{autoload}" )
          puts( " OK".green )
        }
      end
    end
  end
  # End of namespace :capez:autoloads

  # Should be transformed in a simple function (not aimed to be called as a Cap task...)
  namespace :dev do
    desc <<-DESC
      Checks changes on your local installation
      Considers that your main git repo is at the top of your eZ Publish install
      If changes are detected, then ask the user to continue or not
    DESC
    task :local_check do
      if "#{scm}" != "git" then
        abort "Feature only available with git"
      end

      ezroot_path = fetch( :ezpublish_path, false )
      abort "Please set a correct path to your eZ Publish root (:ezpublish_path) or add 'set :ezpublish_path, File.expand_path( File.dirname( __FILE__ ) )' in your Capfile" unless ezroot_path != false and File.exists?(ezroot_path)

      puts( "\n--> Local installation check with git status" )
      git_status = git_status_result( ezroot_path )

      ask_to_abort = false
      if git_status['has_local_changes']
        ask_to_abort = true
        puts( "    - You have local changes" )
      end
      if git_status['has_new_files']
        ask_to_abort = true
        puts( "    - You have untracked files (not under git control)" )
      end

      if ask_to_abort
        user_abort = Capistrano::CLI.ui.ask "    Abort ? y/n (n)"
        abort "Deployment aborted to commit/add local changes".red unless user_abort == "n" or user_abort == ""
      end

      if git_status['tracked_branch_status'] == 'ahead'
        print "    - You have #{git_status['tracked_branch_commits']} commits that need to be pushed"
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
