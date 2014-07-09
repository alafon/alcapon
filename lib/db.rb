namespace :db do
  desc <<-DESC
    Loads one of the backup made with the db:export:remote task
  DESC
  task :import_to_local do
    confirmation = Capistrano::CLI.ui.ask "You are about to replace your local database by a remote backup (selected stage = #{stage}). Are you sure ? y/n (n)"
    if confirmation == "n" or confirmation == ""
      abort "Aborted"
    end
    backup_dir = File.join( get_backup_dir, "#{stage}" )
    backup_list = `ls #{backup_dir}`
    backup_files = backup_list.split( /\n/ );
    files = Hash.new
    i = 1
    backup_files.each { |value|
      puts "#{i}: #{value}"
      files[i] = value
      i += 1
    }
    file_to_import = Capistrano::CLI.ui.ask "Which one ?"
    dbpasswd = fetch( :database_local_passd, "#{database_passd}" )
    if files.has_key?( file_to_import.to_i )
      filename = File.join( backup_dir, files[file_to_import.to_i] )
      system( "gunzip < #{filename} | mysql -u#{database_uname} -p#{dbpasswd} #{database_name} ")
    else
      abort "Bad index"
    end
  end

  # Should use :db as :roles
  desc <<-DESC
    Creates a backup from a remote database server
  DESC
  task :backup, :roles => :web, :only => { :primary => true } do

    do_and_retrieve_backup( "#{database_server}", "#{database_name}", "#{database_uname}", "#{database_passd}" )
    if fetch( :ezdfs_database_server, nil ) != nil
      do_and_retrieve_backup( "#{ezdfs_database_server}", "#{ezdfs_database_name}", "#{ezdfs_database_uname}", "#{ezdfs_database_passd}" )
    end

  end

  desc <<-DESC
    Create a backup from your local instance
  DESC
  task :backup_local do
    backup_dir = File.join( get_backup_dir, 'local' )
    create_backup_dir( backup_dir )
    filename = File.join( backup_dir, generate_backup_name( database_name ) )
    system("mysqldump -u#{database_uname} -p#{database_passd} #{database_name} | gzip -9 > #{filename}")
  end

  def generate_backup_name(dbname)
    return "#{Time.now.strftime '%Y-%m%d-%H%M%S'}-#{dbname}.sql.gz"
  end

  def create_backup_dir( path )
    FileUtils.mkdir_p( path )
  end

  def get_backup_dir
    return "#{ezp_legacy_path('extension/alcapon/backups/database')}"
  end

  def do_and_retrieve_backup( thisdbserver, thisdbname, thisdbuser, thisdbpass )
    filename = generate_backup_name( thisdbname )
    file = File.join( "/tmp", filename )
    backup_dir_for_this_stage = File.join( get_backup_dir, "#{stage}" )
    on_rollback do
      run "rm #{file}"
    end

    dump_result = nil
    run "mysqldump -h#{thisdbserver} -u#{thisdbuser} -p #{thisdbname} | gzip > #{file}" do |ch, stream, out|
      ch.send_data "#{thisdbpass}\n" if out =~ /^Enter password:/
      dump_result = out
    end
    if dump_result =~ /.*error.*1045/i
      puts "Access denied on '#{thisdbserver}' with user '#{thisdbuser}'".red
    else
      create_backup_dir( backup_dir_for_this_stage )
      get( file, File.join( backup_dir_for_this_stage, filename ), :via => :scp )
    end
    run "rm #{file}"
  end
end