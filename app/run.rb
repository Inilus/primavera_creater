#!/usr/bin/env ruby
#
# force_encoding: utf-8
#
# File: run.rb

require 'rubygems'
require 'yaml'        # http://santoro.tk/mirror/ruby-core/classes/YAML.html
require 'progressbar' # http://0xcc.net/ruby-progressbar/index.html.en


require_relative 'environment.rb'

require_relative 'active_record/project.rb'
require_relative 'active_record/task.rb'
require_relative 'active_record/code_type.rb'
require_relative 'active_record/code.rb'
require_relative 'active_record/task_code.rb'

require_relative 'get_project.rb'
#require_relative 'create_project.rb'

class Runner

  def initialize
  	if ARGV.empty? or ARGV[0].nil? or ARGV[1].nil?
  		puts "Incorrect code name project! For example '91.2710'"           if ARGV[0].nil?  		  		
  		puts "Incorrect path or file name! For example 'input/91.2710.xml'" if ARGV[1].nil? 
  		
  		exit( 1 )
		end		
		@config = load_config
		
		@project = GetProject.new( ARGV[0].to_s, ARGV[1].to_s, @config, ( ( ARGV[2] == "-upd" ) ? true : false ) )
		
  end

  def run
    puts "Start..."

    p @project.inspect

#    CreateProject.new( @project, @config )
    
    puts "Finish: Ok!"
  end

  def load_config
  	YAML.load_file( "config/application.yml" )
  end
end

Runner.new.run
