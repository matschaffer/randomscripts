#!/usr/bin/env ruby

# A simple script to find a class definition in a collection of jar files defined by eclipse and available
# in a local maven repository.
#
# Useful for identifying conflicting class definitions across multiple jar files.

classxml = File.read('.classpath')
badlib = ARGV.first

classxml.scan(/M2_REPO(.*)"/).flatten.each do |jar|
 fullpath = "/Users/schapht/.m2/repository" + jar
 puts "Checking #{File.basename(fullpath)}"
 contents = `unzip -l #{fullpath}`
 puts "=== #{badlib} found in #{File.basename(jar)}" unless contents.scan(badlib.gsub(".", "/")).flatten.empty?
end
