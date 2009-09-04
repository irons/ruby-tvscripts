#!/usr/bin/env ruby

# Ruby TV File Mover
# Written by Brian Stolz - brian@tecnobrat.com

###################
# READ THE README #
###################

require 'yaml'
require 'getoptlong'
require "cgi"
require 'pathname'
require 'find'
require 'fileutils'
require 'pp'
require 'time'

def usage()
  puts
  puts "Moves your files into a directory."
  puts 
  puts "Usage: ruby scraper.rb <target-directory-root> [source directory]"
end

def move_files!(filename, destination_path, episode)
  move_file!(filename, destination_path, episode[0], episode[1])
end

def move_file!(filename, destination_path, show, season)
  if show.nil? or season.nil?
    puts "Error getting show data for #{filename}"
    return filename
  end

  show = show.gsub(/\./, " ")

  show = show.split(" ").each{|word| word.capitalize!}.join(" ")
  new_dir = destination_path + Pathname(show) + Pathname("Season #{season}")
  new_filename = new_dir + filename.basename

  #Filename has not changed
  if new_filename == filename
    return filename
  end
  
  if new_filename.file?
    puts "Can not rename #{filename} to #{new_filename} detected a duplicate"
    return filename
  else
    puts "Before: #{filename}"
    puts "Show: #{show}"
    puts "Season: #{season}"
    puts "After:  #{new_filename}"
    puts
    FileUtils.mkdir_p(new_dir)
    File.rename(filename, new_filename) unless filename == new_filename
  end
  
  filename = new_filename
  return filename
end

def get_details(file)
  # figure out what the show is based on path and filename
  season = nil
  show_name = nil
  
  return nil unless  /\d+/ =~ file.basename

  puts file.basename
  
  # check for a match in the style of 1x01
  if /^(.*)[ |\.](\d+)[x|X](\d+)([x|X](\d+))?/ =~ file.basename
    unless $4.nil?
      episode_number2 = $5.to_s
    end
    show_name, season, episode_number = $1.to_s, $2.to_s, $3.to_s
  else 
    # check for s01e01
    if /^(.*)[ |\.][s|S](\d+)[e|E](\d+)([e|E](\d+))?/ =~ file.basename
      unless $5.nil?
        episode_number2 = $5.to_s
      end
      show_name, season, episode_number = $1.to_s, $2.to_s, $3.to_s
    else
      # the simple case
      if /^(.*)[ |\.]\d+/ =~ file.basename
        show_name = $1.to_s
        episode_number = /\d+/.match(file.basename)[0]
        if episode_number.to_i > 99 && episode_number.to_i < 1900 
          # handle the format 308 (season, episode) with special exclusion to year names Eg. 2000 1995
          season = episode_number[0,episode_number.length-2]
          episode_number = episode_number[episode_number.length-2 , episode_number.length]
        end
      end
    end 
  end 
  
  season = season.to_i.to_s

  puts "Show: #{show_name}"
  puts "Season: #{season}"

  return nil if episode_number.to_i > 99
  [show_name, season]
end

# Main program

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

destination_path = ARGV.shift
source_path = ARGV.shift

if not source_path
  source_path = Pathname.new(Dir.getwd)
else
  source_path = Pathname.new(source_path)
end 

if not destination_path
  puts "Error, need destination path"
  usage 
  exit
else
  destination_path = Pathname.new(destination_path)
end 

if not source_path.directory?   
  puts "Directory not found " + source_path	
  usage 
  exit
end

if not destination_path.directory?   
  puts "Directory not found " + destination_path
  usage 
  exit
end

puts "Starting to scan files"
Find.find(source_path.to_s) do |filename|
  Find.prune if [".","..",".ruby-tvmover"].include? filename
  if filename =~ /\.(avi|mpg|mpeg|mp4|divx|mkv)$/ 
    episode = get_details(Pathname.new(filename))
    if episode
      begin 
        move_files!(Pathname.new(filename), destination_path,episode)
      rescue => err
        puts
        puts "Error: #{err}"
        puts
        err.backtrace.each do |line|
          puts line
        end
        puts
      end
    else
      puts "no data found for #{filename}"
    end
  end
end

puts "Done!"
