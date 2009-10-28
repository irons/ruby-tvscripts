#!/usr/bin/env ruby
#

require 'yaml'
require 'rubygems'
require 'getoptlong'
require 'pathname'
require 'find'
require 'fileutils'
require 'pp'
require 'time'
require 'prowl'
require 'logger'
require 'sequel'

def usage()
  puts
  puts "Deletes files from your hard drive that are marked as watched in your XBMC library."
  puts
  puts "Usage: ruby delete-watched.rb <directory>"
  puts
  puts "Directory is optional, will use current directory if its empty."
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

if !ENV["HOME"].nil?
  @@config_dir = "#{ENV["HOME"]}/.ruby-tvscripts"
elsif !ENV["APPDATA"].nil?
  @@config_dir = "#{ENV["APPDATA"]}/.ruby-tvscripts"
else
  @@config_dir = ""
end

if File.exist?("#{@@config_dir}/delete-watched.yml")
  DB_FILE = YAML.load_file( "#{@@config_dir}/delete-watched.yml" )['db_file']
else
  puts "Please create a #{@@config_dir}/delete-watched.yml file with your api key.  Please see example file."
end

puts "Was not able to get DB file, please check #{@@config_dir}/delete-watched.yml file.  Please see example file." if DB_FILE.nil? or DB_FILE.empty?

DB = Sequel.connect("sqlite://#{DB_FILE}")

path = ARGV.shift 

if not path
  path = Pathname.new(Dir.getwd)
else
  path = Pathname.new(path)
end

if not path.directory?
  puts "Directory not found " + path.to_s
  exit
end

MEDIA_DIR = path.to_s

delete_episodes = []

episodes = DB[:episodeview].where('playCount > 0')
episodes.each do |episode|
  file = Pathname.new(episode[:strPath] + episode[:strFileName])
  delete_episodes << file if file.file?
end

if not delete_episodes.nil? and delete_episodes.size > 0

  delete_episodes.each do |file|
    puts file
  end

  puts "Are you sure you want to delete the above files?"
  STDOUT.flush
  answer = gets.chomp
  if answer == "y"
    delete_episodes.each do |file|
      if file.file?
        file.delete
        puts "Deleted #{file}"
      else
        puts "File #{file} does not exist."
      end
    end
  else
    puts "Not deleting files."
  end
else
  puts "No watched episodes found."
end

def check_dirs
  directories = Dir[MEDIA_DIR+'/**/*'].select { |d| File.directory? d }.select { |d| (Dir.entries(d) - %w[ . .. ]).empty? }
  if not directories.nil? and directories.size > 0
    puts
    puts "Do you want to see list of empty directories?"

    STDOUT.flush
    answer2 = gets.chomp
    if answer2 == "y"
      puts
      directories.each { |d| puts d }

      puts
      puts "Should I remove empty directories?"
      STDOUT.flush
      answer3 = gets.chomp
      if answer3 == "y"
        puts
        directories.each do |d|
          Dir.rmdir d
          puts "Deleted #{d}"
        end
      else
        puts
        puts "Not deleting empty directories."
        exit
      end
    else
      puts "Not displaying empty directories."
      exit
    end
  else
    puts "No empty directories found."
    exit
  end
  check_dirs
end

check_dirs
