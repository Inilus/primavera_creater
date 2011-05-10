# force_encoding: utf-8
#
# File: creater.rb
#
# Docs for Yaml: 				http://santoro.tk/mirror/ruby-core/classes/YAML.html

require 'yaml'
#require 'profile'
require_relative 'createrStructure'

class Runner

  def initialize
  	if ARGV.empty? or ARGV[0].nil?
  		puts "Incorrect name project! For example '91.2710'"
  		exit( 1 )
		end
		@name_project = ARGV[0].to_s
    @count = ( ARGV[1] != nil ) ? ARGV[0].to_i : -1    
  end

  def run
    puts "Start..."

    creater = CreaterStructure.new( load_config )
    creater.load_data( @name_project, @count )
    creater.prepare_data
    creater.save_data

    puts "Finish: Ok!"
  end

  def load_config
  	YAML.load_file( "config.yml" )
  end
end

runner = Runner.new
runner.run

