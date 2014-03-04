require 'colored'
require 'digest/md5'

load_paths.push File.expand_path('../', __FILE__)
load "utils"

if( fetch( :ezpublish_version, nil ) == nil )
  alcapon_message( "I am now able to manage versions 4 & 5 of eZ Publish but you
          have to set :ezpublish_version and :ezpublish_subversion
          - in your Capfile like this : set :ezpublish_version, <ezpublish_version>
                                        set :ezpublish_subversion, <ezpublish_subversion>
          - as a command line option : -S ezpublish_version=<ezpublish_version>
                                       -S ezpublish_subverison=<ezpublish_subversion>
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
  capez_puts_done
  print_dotted( "--> Fixing permissions on deployment directory" )
  try_sudo( "chown -R #{user} #{deploy_to}" ) # if not code checkout cannot be done :/
  capez_puts_done
  ezpublish.var.init_shared
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
  capez_puts_done
  # Needed if you want to create extra shared directories under var/ with
  # set :shared_children, [ "var/something",
  #                         "var/something_else" ]
  # Note that :shared_children creates a folder within /shared which name is
  # the last path element (ie: something or something_else) => that's why
  # we cannot use it to create siteaccess' storage folder (var/siteaccess/storage)
  run( "mkdir -p #{latest_release}/#{ezp_legacy_path('var')}" )
end

before "deploy", :roles => :web do
  if fetch( :enable_local_check, false )
    ezpublish.dev.local_check
  end
  deploy.web.disable
end

after "deploy", :roles => :web do
  deploy.web.enable
end

before "deploy:create_symlink" do
  print_dotted( "--> Going live (symlink)", :sol => true )
end

after "deploy:create_symlink" do
  capez_puts_done
end

# Default behavior overrides
namespace :deploy do

  # We don't wan to use xargs rm -rf together with sudo as it's suggested by
  # the default capistrano task
  #
  # Our implementation is not ok either because capture is run on the first
  # server if another server has left the cluster in a certain meantime
  task :cleanup, :except => { :no_release => true } do
    count = fetch(:keep_releases, 4).to_i
    releases = capture "#{try_sudo} ls -1dt #{releases_path}/* | tail -n +#{count + 1}"
    releases.split( /\n/ ).each { |release_path|
      try_sudo "rm -rf #{release_path}"
    }
  end

  namespace :web do
    desc <<-DESC
      Puts a html file somewhere in the documentroot. This file is displayed by a RewriteRule if it exists
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


namespace :ezpublish do
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

          print( "." ) unless dry_run

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

                if( value.count > 0 )

                  # download file if necessary
                  if options[:locally]
                    tmp_filename = target_filename
                  else
                    tmp_filename = target_filename+".tmp"
                    tmp_filename = Digest::MD5.hexdigest( tmp_filename )
                    if dry_run
                      puts "\n"
                      puts "tmp_filename : #{tmp_filename}"
                      puts "target_filepath : #{path}/#{target_filename}"
                    else
                      get( "#{path}/#{target_filename}", tmp_filename, :via => :scp )
                    end
                  end

                  if !dry_run
                    text = File.read(tmp_filename)
                  end
                  value.each { |search,replace|
                    changes += 1
                    if dry_run
                      puts "replace '#{search}' by '#{replace}'"
                    else
                      text = text.gsub( "#{search}", "#{replace}" )
                    end
                  }

                  if !dry_run
                    File.open(tmp_filename, "w") {|file| file.write(text) }
                  end

                  # upload and remove temporary file
                  if !options[:locally] && !dry_run
                    run( "if [ -f #{target_filename} ]; then rm #{target_filename}; fi;" )
                    upload( tmp_filename, "#{path}/#{target_filename}", :via => :scp )
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

  namespace :var do
    desc <<-DESC
      Creates the needed folder within your remote(s) var directories
    DESC
    task :init_shared, :roles => :web do
      puts( "--> Creating eZ Publish var directories" )
      print_dotted( "var " )
      run( "mkdir -p #{shared_path}/var" )
      capez_puts_done

      print_dotted( "var/storage" )
      run( "mkdir -p #{shared_path}/var/storage" )
      capez_puts_done

      storage_directories.each{ |sd|
        print_dotted( "var/#{sd}/storage" )
        run( "mkdir -p #{shared_path}/var/#{sd}/storage" )
        capez_puts_done
      }
      run( "chmod -R g+w #{shared_path}/var")
      try_sudo( "chgrp -R #{fetch(:webserver_group,:user)} #{shared_path}/var")
    end



    desc <<-DESC
      [internal] Creates release directories
    DESC
    task :init_release, :roles => :web do
      puts( "\n--> Release directories" )

      if( ezp5? )
        folders_path = [ "ezpublish/cache", "ezpublish/config", "ezpublish/logs", "#{fetch('ezp5_assets_path','web')}" ]
        folders_path.each{ |fp|
          print_dotted( "#{fp}" )
          run( "mkdir -p #{latest_release}/#{fp}")
          run( "chmod -R g+wx #{latest_release}/#{fp}" )
          try_sudo( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{latest_release}/#{fp}" )
          capez_puts_done
        }
      end

      # creates a storage dir for elements specified by :storage_directories
      storage_directories.each{ |sd|
        print_dotted( "var/#{sd}/storage" )
        run( "mkdir #{latest_release}/" + ezp_legacy_path( "var/#{sd}" ) )
        capez_puts_done
      }

      # makes sure the webserver can write into var/
      run( "chmod -R g+w #{latest_release}/" + ezp_legacy_path( "var" ) )
      try_sudo( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{latest_release}/" + ezp_legacy_path( "var" ) )

      # needed even if we just want to run 'bin/php/ezpgenerateautoloads.php' with --extension
      # autoload seems to be mandatory for "old" version such as 4.0, 4.1, ...
      print_dotted( ezp_legacy_path( "autoload" ) )
      autoload_path = File.join( latest_release, ezp_legacy_path( 'autoload' ) )
      run( "if [ ! -d #{autoload_path} ]; then mkdir -p #{autoload_path}; fi;" )
      capez_puts_done
      try_sudo( "chown -R #{fetch(:webserver_user,:user)}:#{fetch(:webserver_group,:user)} #{autoload_path}" )
    end

    desc <<-DESC
      Link .../shared/var into ../releases/[latest_release]/var
    DESC
    task :link, :roles => :web do
      puts( "\n--> Symlinks" )

      print_dotted( "var/storage" )
      try_sudo( "ln -s #{shared_path}/var/storage #{latest_release}/" + ezp_legacy_path( "var/storage" ) )
      capez_puts_done

      storage_directories.each{ |sd|
        print_dotted( "var/#{sd}/storage" )
        try_sudo( "ln -s #{shared_path}/var/#{sd}/storage #{latest_release}/" + ezp_legacy_path( "var/#{sd}/storage" ), :as => webserver_user )
        capez_puts_done
      }

      try_sudo( "chmod -R g+w #{latest_release}/" + ezp_legacy_path( "var" ) )
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
  # End of namespace ezpublish:var

  # TODO : cache management must be aware of cluster setup  namespace :autoloads do
  namespace :autoloads do
    desc <<-DESC
      Generates autoloads (extensions and kernel overrides)
    DESC
    task :generate, :roles => :web do
      if autoload_list.count == 0
        print_dotted( "--> eZ Publish autoloads (disabled)", :sol => true )
        capez_puts_done
      else
        puts( "\n--> eZ Publish autoloads " )
        autoload_list.each { |autoload|
          print_dotted( "#{autoload}" )
          run( "cd #{latest_release}/#{ezp_legacy_path} && sudo -u #{fetch(:php_user,:user)} php bin/php/ezpgenerateautoloads.php --#{autoload}" )
          capez_puts_done
        }
      end
    end
  end
  # End of namespace ezpublish:autoloads

  # Should be transformed in a simple function (not aimed to be called as a Cap task...)
  # Considers that your main git repo is at the top of your eZ Publish install
  # If changes are detected, then ask the user to continue or not
  namespace :dev do
    desc <<-DESC
      Check if there are any changes on your local installation based on what your scm knows
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
