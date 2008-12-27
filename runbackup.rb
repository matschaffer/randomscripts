#!/usr/bin/env ruby

require 'logger'

class Backup
  attr_accessor :name, :root, :timestamp_format, :workspace
  attr_reader :log, :time

  def initialize(config_file)
    @log = Logger.new(STDOUT)
    log.level = Logger::DEBUG

    # Assume project name is backup config name
    self.name = File.basename(config_file).split('.').first

    # Assume project root is sibling to backup config and has same name
    self.root = File.join(File.dirname(config_file), name)

    # Assume folder containing backup config is safe workspace
    self.workspace = File.dirname(config_file)

    self.timestamp_format = '%Y%m%d%H%M%S'

    @temporary_files = []
    @time = Time.now

    instance_eval(File.read(config_file))
  end

  def run(command)
    log.debug "Running #{command}"
    system command
  end

  def start
    log.info "Starting Backup of #{root} at #{time}"
    db_backup
    package_files
    archive_files
    cleanup_temporary_files
  end

  def package_filename
    File.join workspace, "#{name}-#{time.strftime(timestamp_format)}.tar.bz2"
  end

  def package_files
    run "tar -C #{File.dirname(root)} -jcf #{package_filename} #{File.basename(root)}"
    @temporary_files << "#{package_filename}"
  end

  def db_backup
    if @db_command
      dumpfile = File.join(root, "#{name}.db")
      log.info "Backing up database"
      run "#{@db_command} > #{dumpfile}"
      @temporary_files << dumpfile
    end
  end

  def archive_files
    if @archive_command
      log.info "Archiving package"
      run @archive_command
    end
  end

  def cleanup_temporary_files
    log.info "Cleaning up temporary files"
    @temporary_files.each do |file|
      run "rm #{file}"
    end
  end

  def keep(config)
    @number_to_keep = config
  end

  def mysql(config)
    @db_command = "mysqldump"
    @db_command += " -h#{config[:host]}" if config[:host]
    @db_command += " -u#{config[:user]}" if config[:user]
    @db_command += " -p#{config[:password]}" if config[:password]
    @db_command += " #{config[:database]}"
  end

  def sftp(config)
    sftp_command = "put #{package_filename}"
    sftp_command += " #{config[:folder]}" if config[:folder]
    sftp_host = ""
    sftp_host += "#{config[:user]}@" 
    sftp_host += config[:host] 
    @archive_command = "echo '#{sftp_command}' | sftp -b - #{sftp_host}" 
  end
end

ARGV.each { |f| Backup.new(f).start }
