#!/usr/bin/env ruby

require 'rubygems'
require 'digest/sha1'
require 'nokogiri'

repo, author, since = ARGV

digest = Digest::SHA1.hexdigest(since + repo)
log = digest + ".log"
system "svn log -rHEAD:'{#{since}}' --xml #{repo} > #{log}" unless File.exists?(log)

log = Nokogiri(File.read(log))

FileUtils.mkdir_p(digest)
Dir.chdir(digest) do
  log.search("//logentry/author[contains(.,'#{author}')]").each do |e|
    revision = e.parent['revision']
    system "svn log -r #{revision} #{repo} > #{revision}.diff"
    system "svn diff -c #{revision} #{repo} >> #{revision}.diff"
    puts "Processed revision #{revision}"
  end
end