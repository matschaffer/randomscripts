
require 'logger'
require 'yaml'
require 'rubygems'
require 'ruby-debug'
require 'net/http'
require 'rexml/document'

module Logging
  def init_log
    @log = Logger.new(STDOUT)
    @log.level = Logger::WARN
  end
  
  def log
    init_log unless @log
    @log
  end
end

class Lineup < Hash
  def compare(b)
    matches = []
    self.each do |channel, details|
      if b[channel] && b[channel][:name] == details[:name]
        matches << details
      end
    end
    return matches
  end
  
  def compare_and_print(b, name)
    compare(b).each { |m| puts "Lineup #{name} has the same channel for #{m[:channel]}:#{m[:name]}" }
  end
end

class DACParser
  include Logging
  
  attr_reader :lineups
  
  def initialize
    @lineups = []
    @lineup = Lineup.new
  end
  
  def reading?
    @reading
  end

  def start_reading(line)
    log.debug 'Started trying to parse map debug' unless reading?
    @reading = true
    @column_widths = line.split(/\s+/).map { |hr| hr.length }
  end

  def stop_reading
    log.debug 'Stopped trying to parse map debug' if reading?
    @reading = false
    if @lineup && !@lineup.empty?
      @lineups << @lineup
      @lineup = Lineup.new
    end
  end
  
  def parse_line(line)
    parts = []
    @column_widths.inject(0) do |pos, width|
      parts << line[pos,width].strip
      pos + width + 1
    end

    log.debug("Parsed #{parts.inspect} from #{line}")

    channel, name, type, device, port_name, frequency = parts
    @lineup[channel.to_i] = {:channel => channel.to_i,
                               :name => name,
                               :type => type,
                               :device => device,
                               :port_name => port_name,
                               :frequency => frequency.to_f}
  end
  
  def parse_file(file)
    File.new(file, 'r').each_line do |line|
      if line =~ /^-+/
        start_reading(line)
      elsif line =~ /^\s+$/ || line =~ /^\(/
        stop_reading
      elsif reading?
        parse_line(line)
      end
    end
  end
end

class StreamSageParser
  include Logging
  
  attr_reader :lineups
  
  def initialize
    @lineups = []
  end
  
  def parse_zip(zip)
    url = "http://www.comcast.net/zip?zip=#{zip}"
    log.debug "Requesting lineups list for zipcode #{zip} from #{url}"
    
    doc = REXML::Document.new(Net::HTTP.get(URI.parse(url)))
    tag = doc.elements.to_a('headends/headend').find { |e| e.attributes['title'] =~ /digital/i }
    id = tag.attributes['id']
    title = tag.attributes['title']
    
    log.debug("Selected headend '#{title}' with id #{id}")
    parse_headend(id)
  end
  
  def parse_headend(id)
    url = "http://www.comcast.net/lineup?headendid=#{id}"
    log.debug "Requesting lineup details from #{url}"
    doc = REXML::Document.new(Net::HTTP.get(URI.parse(url)))
    
    lineup = Lineup.new
    doc.elements.each("lineups/lineup") do |e|
      channel = e.attributes['channel_number'].to_i
      name = e.attributes['title']
      lineup[channel] = { :channel => channel, :name => name }
    end
    
    @lineups << lineup
  end
end

ssp = StreamSageParser.new
ssp.parse_zip(19335)

dp = DACParser.new
dp.parse_file('DAC 2_channel_3_27_09.txt')

match_sets = []
dp.lineups.each_with_index do |lineup, i|  
  match_sets << ssp.lineups.first.compare(lineup)
end

matching_channels = match_sets.map { |match_set| match_set.map { |match| match[:channel] } }.flatten.sort
match_counts = Hash.new { |h,k| h[k] = 0 }

matching_channels.each { |channel| match_counts[channel] += 1 }
fully_matching_channels = match_counts.map { |k,v| k if v == 7 }.compact.sort

puts "Fully matching channels: #{fully_matching_channels.join(',')}"
