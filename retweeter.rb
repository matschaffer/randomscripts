#!/usr/bin/env ruby
require 'open-uri'
require 'rexml/document'
require 'net/http'

TWITTER_USER = "" # User name to tweet as
TWITTER_PASS = "" # Password for that account
RETWEET_CODE = "" # This code is given out to trusted people allowed to retweet

LAST_TWEET_FILE = "#{ENV['HOME']}/.last_tweet_code" # File that keeps track of the ID of last tweeted DM.

def last_tweet
  @last_tweet ||= open(LAST_TWEET_FILE).read rescue 0
end

def url
  "http://twitter.com/direct_messages.xml?since_id=#{last_tweet}"
end

def dm_from_twitter
  open(url, :http_basic_authentication => [TWITTER_USER, TWITTER_PASS]).read
end

def direct_messages
  @direct_messages ||= dm_from_twitter
end

def update_last_tweet(tweet_id)
  File.open(LAST_TWEET_FILE, "w") do |f|
    f.puts tweet_id
  end
end

def send_update(tweet)
  Net::HTTP.post_form(URI.parse("http://#{TWITTER_USER}:#{TWITTER_PASS}@twitter.com/statuses/update.json"),
    {'status' => tweet}
  )
end

def valid?(tweet)
  !tweet.match(/\b#{RETWEET_CODE}\b/).nil?
end

def strip(tweet)
  tweet.gsub(/\b#{RETWEET_CODE}\b\s*/, '')
end

direct_messages.reverse.each do |dm|
  next if dm["id"] == last_tweet
  tweet = "#{strip(dm["text"])}" if valid?(dm["text"])
  send_update(tweet)
end

update_last_tweet(direct_messages.first["id"]) if direct_messages.first