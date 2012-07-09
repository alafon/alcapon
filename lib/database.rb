namespace :database do
  namespace :backup do
    # Should use :db as :roles
    task :remote do
      filename = "backup-cap.#{Time.now.strftime '%Y-%m%d-%H%M%S'}.sql.gz"
      file = "/tmp/"+filename;
        on_rollback do
          run "rm #{file}"
        end
      run "mysqldump -u#{database_uname} -p#{database_passd} #{database_name} | gzip -9 > #{file}"
      `mkdir -p #{File.dirname(__FILE__)}/../backups/database`
      get file, "backups/database/#{filename}"
      run "rm #{file}"
    end

    task :load_locally do
      confirmation = Capistrano::CLI.ui.ask "You are about to replace your local database by a production backup. Are you sure ? y/n (n)"
      if confirmation == "n" or confirmation == ""
        abort
      end
      backup_list = `ls #{File.dirname(__FILE__)}/../backups/database`
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
        system( "gunzip < #{File.dirname(__FILE__)}/../backups/database/#{files[file_to_import.to_i]} | mysql -u#{database_uname} -p#{database_passd} #{database_name} ")
      else
        abort "Bad index"
      end
    end
  end
end