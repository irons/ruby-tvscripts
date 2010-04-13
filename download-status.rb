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
require 'prowl'

def usage()
  puts
  puts "Moves your files into an organized directory"
  puts
  puts "Usage: ruby download-status.rb <directory>"
  puts
  exit
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

if File.exist?("#{@@config_dir}/download-status.yml")
  PROWL_API = YAML.load_file( "#{@@config_dir}/download-status.yml" )['prowl_api']
else
  puts "Please create a #{@@config_dir}/download-status.yml file with your api key.  Please see example file."
end

puts "Was not able to set API Key, please check #{@@config_dir}/download-status.yml file.  Please see example file." if PROWL_API.nil? or PROWL_API.empty?

path = ARGV.shift

if not path
  path = Pathname.new(Dir.getwd)
else
  path = Pathname.new(path)
end 

if not path.directory?   
  puts "Directory not found " + path	
  exit
end

cache_file = Pathname.new("#{@@config_dir}/download_cache.txt")

@@download_cache = {}

cache_file.readlines.each { |line|
    arr = line.chomp.split("|||||")
    @@download_cache.merge!({arr[1] => Time.parse(arr[0])})
} if cache_file.file?

found = []

Find.find(path.to_s) do |filename|
  Find.prune if [".","..",".ruby-tvmover"].include? filename
  if filename =~ /\.(avi|mpg|mpeg|mp4|divx|mkv)$/
    if @@download_cache[filename].nil?
      found << filename
      @@download_cache.merge!({filename => Time.now})
    end
  end
end

if found.size > 0
  puts "Found #{found.size} new files:\n"
  output = ""
  found.each do |file|
    output += file.gsub!(/.*\//, "") + "\n"
  end
  puts output

  Prowl.add(
    :apikey => PROWL_API,
    :application => "DLS",
    :event => "#{found.size} File(s) Downloaded",    
    :description => output
  )
else
  puts "Found no files"
end

FileUtils.mkdir(@@config_dir) unless Pathname.new("#{@@config_dir}").directory?

Pathname.new("#{@@config_dir}/download_cache.txt").delete if Pathname.new("#{@@config_dir}/download_cache.txt").file?
@@download_cache.each do |filename,time|
  Pathname.new("#{@@config_dir}/download_cache.txt").open("a")  {|file| file.puts "#{time}|||||#{filename.to_s}"}
end

puts "Finished at #{Time.now}"
puts
