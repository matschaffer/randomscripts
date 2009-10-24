#!/usr/bin/env ruby

# A simple script to find a class definition in a collection of jar files defined by eclipse and available
# in a local maven repository.
#
# Useful for identifying conflicting class definitions across multiple jar files.

require 'pathname'
require 'rubygems'
require 'hpricot'

needle = ARGV.first

def lookfor(needle, jar)
  basename = File.basename(jar)
  puts "Checking #{basename}"
  contents = `unzip -l #{jar}`
  puts "=== #{needle} found in #{basename}" unless contents.scan(needle.gsub(".", "/")).flatten.empty?
end

begin
  classxml = Hpricot(File.read('.classpath'))
  classxml.search("classpathentry").each do |cpentry|
    if Pathname.new(cpentry['path']).extname == '.jar'
      lookfor needle, cpentry['path'].gsub('M2_REPO', '~/.m2/repository')
    end
  end
rescue Errno::ENOENT
  # no .classpath, just loop over all the jars in pwd
  Dir["*.jar"].each { |jar| lookfor needle, jar }
end
