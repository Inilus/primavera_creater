#!/usr/bin/env ruby
#
# force_encoding: utf-8
#
# File: run.rb

require_relative 'xml_reader.rb'

class Runner

  def initialize
  	if ARGV.empty? or ARGV[0].nil? or ARGV[1].nil?  	  
  		puts "Incorrect code name project! For example '91.2710'" if ARGV[0].nil?
  		puts "Incorrect path or file name! For example 'input/91.2710.xml'"     if ARGV[1].nil?
  		
  		exit( 1 )
		end		
		
		@project = XmlReader.new( ARGV[0].to_s, ARGV[1].to_s, load_config )
		
  end

  def run
    puts "Start..."

    
    puts "Finish: Ok!"
  end

  def load_config
  	YAML.load_file( "config/application.yml" )
  end
end

Runner.new.run
