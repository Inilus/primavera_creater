#!/usr/bin/env ruby
#
# force_encoding: utf-8
#
# File: run.rb

require 'rubygems'
require 'yaml'        # http://santoro.tk/mirror/ruby-core/classes/YAML.html
require 'progressbar' # http://0xcc.net/ruby-progressbar/index.html.en
require 'active_record'   # http://snippets.dzone.com/posts/show/3097 # http://habrahabr.ru/blogs/ruby/98751/
require 'logger'

require File.expand_path( "../environment", __FILE__ )
require File.expand_path( "../active_record/project", __FILE__ )
require File.expand_path( "../active_record/task", __FILE__ )
require File.expand_path( "../active_record/code_type", __FILE__ )
require File.expand_path( "../active_record/code", __FILE__ )
require File.expand_path( "../active_record/task_code", __FILE__ )

require File.expand_path( "../get_project", __FILE__ )
require File.expand_path( "../create_project", __FILE__ )

class Runner

  def initialize
    if ARGV.empty? or ARGV[0].nil? or ARGV[1].nil?
      puts "Incorrect code name project! For example '91.2710'"           if ARGV[0].nil?
      puts "Incorrect path or file name! For example 'input/91.2710.xml'" if ARGV[1].nil?
      exit( 1 )
    end

    @config = load_config

    @project = GetProject.new( ARGV[0].to_s, ARGV[1].to_s, @config, ( ( ARGV[2] == "-upd" ) ? true : false ) ).get_project

  end

  def run
    CreateProject.new( @config ).save_data( @project )
    puts "Finish: Ok!"
  end

  private

    def load_config
      YAML.load_file( File.expand_path( "../../config/application.yml", __FILE__ ) )
    end
end

Runner.new.run

