#!/usr/bin/env ruby

# Ruby download notifier
# Written by Brian Stolz - brian@tecnobrat.com

###################
# READ THE README #
###################

require 'yaml'
require 'rubygems'
require 'getoptlong'
require 'pathname'
require 'find'
require 'fileutils'
require 'pp'
require 'time'
require 'sequel'
require 'net/http'
require 'uri'
require 'json'


def usage()
  puts
  puts "Moves your files into an organized directory"
  puts
  puts "Usage: ruby trakt-library-import.rb"
  puts
  exit
end

def save_cache
  FileUtils.mkdir(@@config_dir) unless Pathname.new("#{@@config_dir}").directory?
  
  Pathname.new("#{@@config_dir}/trakt_cache.yml").delete if Pathname.new("#{@@config_dir}/trakt_cache.yml").file?
  Pathname.new("#{@@config_dir}/trakt_cache.yml").open("w")  {|file| file.puts @@trakt_cache.to_yaml}
end

parser = GetoptLong.new
parser.set_options(
  ["-h", "--help", GetoptLong::NO_ARGUMENT]
)

loop do
  opt, arg = parser.get
  break if not opt
  case opt
    when "-h"
      usage
      break
  end
end


puts "Starting at #{Time.now}"

if !ENV["HOME"].nil?
  @@config_dir = "#{ENV["HOME"]}/.ruby-tvscripts"
elsif !ENV["APPDATA"].nil?
  @@config_dir = "#{ENV["APPDATA"]}/.ruby-tvscripts"
else
  @@config_dir = ""
end

if File.exist?("#{@@config_dir}/trakt-import.yml")
  SETTINGS = YAML.load_file( "#{@@config_dir}/trakt-import.yml" )
else
  puts "Please create a #{@@config_dir}/trakt-import.yml file with your DB info, api key, username and password hash.  Please see example file."
end

puts "Was not able to get DB file, please check #{@@config_dir}/trakt-import.yml file.  Please see example file." if SETTINGS.nil? or SETTINGS.empty?
puts "DB settings need to include an engine type" if SETTINGS['database']['engine'].nil?

database = SETTINGS['database']
case database['engine']
when 'mysql'
  DB = Sequel.connect("mysql://#{database['user']}:#{database['password']}@#{database['host']}/#{database['db']}")
when 'sqlite'
  DB = Sequel.connect("sqlite://#{database['file']}")
end

@episodes = {}
@episodes[:library] = {}
@episodes[:seen] = {}

if File.exist?("#{@@config_dir}/trakt_cache.yml")
  @@trakt_cache = YAML.load_file( "#{@@config_dir}/trakt_cache.yml" )
else
  @@trakt_cache = {}
end

puts "Loaded cache"

@@trakt_cache[:library] = {} if @@trakt_cache[:library].nil?
@@trakt_cache[:seen] = {} if @@trakt_cache[:seen].nil?

episodes = DB["select episodeview.c12 as season, episodeview.c13 as episode, tvshow.c00 as title, tvshow.c12 as tvdb_id from episodeview join tvshow on tvshow.idShow = episodeview.idShow"]
episodes.each do |episode|
  tvdb_id = episode[:tvdb_id].to_s
  if @@trakt_cache[:library][tvdb_id].nil? or @@trakt_cache[:library][tvdb_id][episode[:season]].nil? or @@trakt_cache[:library][tvdb_id][episode[:season]].index(episode[:episode]).nil?
    @episodes[:library][tvdb_id] = {:title => episode[:title], :tvdb_id => tvdb_id.to_i, :episodes => []} if @episodes[:library][tvdb_id].nil?
    @episodes[:library][tvdb_id][:episodes] << {:season => episode[:season].to_i, :episode => episode[:episode].to_i}
  end
end

episodes = DB["select episodeview.c12 as season, episodeview.c13 as episode, tvshow.c00 as title, tvshow.c12 as tvdb_id from episodeview join tvshow on tvshow.idShow = episodeview.idShow where episodeview.playCount > 0"]
episodes.each do |episode|
  tvdb_id = episode[:tvdb_id].to_s
  if @@trakt_cache[:seen][tvdb_id].nil? or @@trakt_cache[:seen][tvdb_id][episode[:season]].nil? or @@trakt_cache[:seen][tvdb_id][episode[:season]].index(episode[:episode]).nil?
    @episodes[:seen][tvdb_id] = {:title => episode[:title], :tvdb_id => tvdb_id.to_i, :episodes => []} if @episodes[:seen][tvdb_id].nil?
    @episodes[:seen][tvdb_id][:episodes] << {:season => episode[:season].to_i, :episode => episode[:episode].to_i}
    unless @@trakt_cache[:library][tvdb_id].nil? or @@trakt_cache[:library][tvdb_id][episode[:season]].nil? or @@trakt_cache[:library][tvdb_id][episode[:season]].index(episode[:episode]).nil?
      @@trakt_cache[:library][tvdb_id][episode[:season]].delete_if {|e| e == episode[:episode]}
    end
  end
end

LOGIN = {'username' => SETTINGS['username'], 'password' => SETTINGS['password']}

@episodes[:library].each do |tvdb_id, tvshow|
  tvdb_id = tvdb_id.to_s
  #Submit data
  json_data = tvshow.merge(LOGIN).to_json
  url = URI.parse("http://api.trakt.tv/show/episode/library/#{SETTINGS['apikey']}")
  puts "Posting to #{url}"
  puts json_data
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.post(url.path, json_data)
    }
    puts res.body
    tvshow[:episodes].each do |episode|
      @@trakt_cache[:library][tvdb_id] = {} if @@trakt_cache[:library][tvdb_id].nil?
      @@trakt_cache[:library][tvdb_id][episode[:season].to_s] = [] if @@trakt_cache[:library][tvdb_id][episode[:season].to_s].nil?
      @@trakt_cache[:library][tvdb_id][episode[:season].to_s] << episode[:episode].to_s
    end
  rescue e
    puts "Failed to post: #{e}"
  end
  save_cache
  puts "Finished posting, sleeping for 1 second"
  sleep 1
  puts
end

@episodes[:seen].each do |tvdb_id, tvshow|
  tvdb_id = tvdb_id.to_s
  #Submit data
  json_data = tvshow.merge(LOGIN).to_json
  url = URI.parse("http://api.trakt.tv/show/episode/seen/#{SETTINGS['apikey']}")
  puts "Posting to #{url}"
  puts json_data
  begin
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.post(url.path, json_data)
    }
    puts res.body
    tvshow[:episodes].each do |episode|
      @@trakt_cache[:seen][tvdb_id] = {} if @@trakt_cache[:seen][tvdb_id].nil?
      @@trakt_cache[:seen][tvdb_id][episode[:season].to_s] = [] if @@trakt_cache[:seen][tvdb_id][episode[:season].to_s].nil?
      @@trakt_cache[:seen][tvdb_id][episode[:season].to_s] << episode[:episode].to_s
    end
  rescue e
    puts "Failed to post: #{e}"
  end
  save_cache
  puts "Finished posting, sleeping for 1 second"
  sleep 1
  puts
end

save_cache

puts "Finished at #{Time.now}"
puts
