#!/usr/bin/env ruby
# force_encoding: utf-8
#
# File: xml_reader.rb

require 'rubygems'
require 'nokogiri'    # http://nokogiri.org/
require 'open-uri'

require_relative 'environment.rb'

require_relative 'active_record/project.rb'
require_relative 'active_record/task.rb'
require_relative 'active_record/code_type.rb'
require_relative 'active_record/code.rb'
require_relative 'active_record/task_code.rb'


@xmldoc = Nokogiri::XML(File.open("input/91.2711-dev.xml"))
root = @xmldoc.xpath("//PRODUCTS")
puts "Root element : " + root.attribute("type")

@xmldoc.xpath("//PRODUCTS/PRODUCT").each do |product|
  puts product.attribute("name")
end


