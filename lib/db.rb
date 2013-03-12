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
    if files.has_key?( file_to_import.to_i )
      filename = File.join( backup_dir, files[file_to_import.to_i] )
      system( "gunzip < #{filename} | mysql -u#{database_uname} -p#{database_passd} #{database_name} ")
    else
      abort "Bad index"
    end
  end

  # Should use :db as :roles
  desc <<-DESC
    Creates a backup from a remote database server
  DESC
  task :backup, :roles => :db do
    filename = generate_backup_name
    file = File.join( "/tmp", filename )
      on_rollback do
        run "rm #{file}"
      end
    run "mysqldump -u#{database_uname} -p#{database_passd} #{database_name} | gzip > #{file}"
    backup_dir_for_this_stage = File.join( get_backup_dir, "#{stage}" )
    create_backup_dir( backup_dir_for_this_stage )
    get file, File.join( backup_dir_for_this_stage, filename )
    run "rm #{file}"
  end

  desc <<-DESC
    Create a backup from your local instance
  DESC
  task :backup_local do
    backup_dir = File.join( get_backup_dir, 'local' )
    create_backup_dir( backup_dir )
    filename = File.join( backup_dir, generate_backup_name )
    system("mysqldump -u#{database_uname} -p#{database_passd} #{database_name} | gzip -9 > #{filename}")
  end

  def generate_backup_name
    return "#{Time.now.strftime '%Y-%m%d-%H%M%S'}.sql.gz"
  end

  def create_backup_dir( path )
    FileUtils.mkdir_p( path )
  end

  def get_backup_dir
    return "#{ezp_legacy_path('extension/alcapon/backups/database')}"
  end
end