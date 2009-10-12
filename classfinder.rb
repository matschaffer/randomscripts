#!/usr/bin/env ruby

# A simple script to find a class definition in a collection of jar files defined by eclipse and available
# in a local maven repository.
#
# Useful for identifying conflicting class definitions across multiple jar files.

require 'pathname'
require 'rubygems'
require 'hpricot'

classxml = Hpricot(File.read('.classpath'))
badlib = ARGV.first

classxml.search("classpathentry").each do |cpentry|
  if Pathname.new(cpentry['path']).extname == '.jar'
    jar = cpentry['path'].gsub('M2_REPO', '~/.m2/repository')
    puts "Checking #{File.basename(jar)}"
    contents = `unzip -l #{jar}`
    puts "=== #{badlib} found in #{File.basename(jar)}" unless contents.scan(badlib.gsub(".", "/")).flatten.empty?
  end
end
