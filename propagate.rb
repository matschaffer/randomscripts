#!/usr/bin/env ruby
# $Id: propagate 351 2009-05-29 17:50:45Z mschaffe $
require 'pathname'
require 'rexml/document'
require 'fileutils'

def usage
  <<EOF
Usage: #{File.basename($0)} <changeset>

Merges the given changeset from your current branch into any sibling 
branches that are alphabetically higher than the current branch.

Your current branch is:
  - #{working_copy_url}

Running propagate from this branch will merge into the following branches:
  - #{greater_siblings(working_copy_url).join("\n  - ")}
EOF
end

def working_copy_url(path = ".")
  `svn info #{path}`.match(/URL: (.*)$/)[1]
end

def greater_siblings(url)
  directory = url_split(url).last
  siblings(url).find_all { |s| s > directory }
end

def siblings(url)
  ls(parent(url)).map do |item|
    item[0..-2] if item =~ /\/$/
  end.compact
end

def ls(url)
  `svn ls "#{url}"`.split(/\n/)
end

def url_split(url)
  Pathname.new(url).split.map { |p| p.to_s }
end

def parent(url)
  url_split(url).first
end

def log(changeset, url)
  log = `svn log --xml -r #{changeset} #{url}`
  abort unless log
  REXML::Document.new(log).root.elements['logentry'].elements['msg'].text or '' rescue abort "Changeset #{changeset} doesn't exist on this branch."
end

def update(remote, local)
  if File.exist?(local)
    puts "Updating local copy of #{local}..."
    `svn up "#{local}"`
  else
    puts "Checking out #{remote} to #{local}..."
    `svn co "#{remote}" "#{local}"`
  end
end

def using_svn_1_5?
  `svn --version` =~ /version 1\.5/
end

def merge(from, to, source, dryrun = false)
  command = %(svn merge -r#{from}:#{to} "#{source}")
  command += " --dry-run" if dryrun
  command += " --accept postpone" if using_svn_1_5?
  changed_files(command)
end

def cleanup(message_file, targets_file)
  FileUtils.rm message_file
  FileUtils.rm targets_file
end

def commit(message_file, targets_file)
  if File.size(targets_file) > 0
    system("svn commit -F #{message_file} --targets #{targets_file}") and cleanup(message_file, targets_file)
  else
    cleanup(message_file, targets_file) and puts "No files changed."
  end
end

def status_message?(line)
  line =~ /Skipped.*:/ or line =~ /Merging.*:/ or line =~ /conflicts:/
end

def changed_files(command = "svn status")
  changed_files = []
  IO.popen(command, 'r') do |out|
    out.each_line do |line|
      changed_files += line.scan(/\w+\s+(.*)$/).flatten unless status_message?(line)
    end
  end
  return changed_files
end

def each_sibling(url)
  greater_siblings(url).each do |sibling|
    sibling_url = parent(url) + "/" + sibling
    sibling_working_copy = File.join('..', sibling)
  
    update(sibling_url, sibling_working_copy)
  
    Dir.chdir(sibling_working_copy) do
      yield sibling
    end
  end
end

def message_file(changeset)
  "propagate_#{changeset}_message.tmp"
end

def targets_file(changeset)
  "propagate_#{changeset}_targets.tmp"
end

def pending_propagation_for?(changeset)
  File.exist?(message_file(changeset)) and File.exist?(targets_file(changeset))
end

def check_for_outstanding_changes(changeset, url)
  each_sibling(url) do |sibling|
    if not pending_propagation_for?(changeset)
      puts "Examining #{sibling} for outstanding changes..."
      merged_files = merge(changeset - 1, changeset, url, :dryrun)
      already_changed_files = merged_files & changed_files 

      if not already_changed_files.empty?
        puts "Could not propagate changeset #{changeset} into branch #{sibling} because these files have outstanding changes:"
        already_changed_files.each { |f| puts "  ../#{sibling}/#{f}" }
        puts "\nPlease commit or revert these files before propagation."
        abort
      end
    end
    puts
  end
end

def perform_merge(changeset, url)
  each_sibling(url) do |sibling|
    if pending_propagation_for?(changeset)
      puts "Found temporary files for changeset #{changeset}, will retry commit."
    else
      puts "Merging into #{sibling}:"
      merged_files = merge(changeset - 1, changeset, url)
      File.open(message_file(changeset), 'w') { |f| f.print "Propagating [#{changeset}]: " + log(changeset, url) }
      File.open(targets_file(changeset), 'w') { |f| f.print merged_files.join("\n") }
    end

    commit(message_file(changeset), targets_file(changeset)) and puts "Propagation to #{sibling} complete."
    puts
  end
end

def propagate(changeset, url)
  log(changeset, url) # Trying to pull a log will cause early failure if specified changeset is not found
  check_for_outstanding_changes(changeset, url)
  perform_merge(changeset, url)
end

def cwd_is_working_copy?
  File.exist?('.svn') or File.exist?('_svn')
end

def parent_folder_is_from_same_working_copy?
  if File.exist?(File.join('..', '.svn')) or File.exist?(File.join('..', '_svn'))
    working_copy_url.index(working_copy_url('..')) == 0
  end
end

def in_working_copy_root?
  cwd_is_working_copy? and not parent_folder_is_from_same_working_copy?
end

if in_working_copy_root?
  changeset = (ARGV[0] or abort(usage)).to_i
  propagate(changeset, working_copy_url)
else
  abort "Please run #{File.basename($0)} from the root of a subversion working copy."
end
