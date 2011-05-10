# force_encoding: utf-8
#
# File: xml_reader.rb

require 'rubygems'
require 'rexml/document'  # http://ruby.inuse.ru/article/obrabotka-xml-xpath-i-xsl-transformacii-v-ruby
require 'yaml'

require_relative 'environment.rb'

require_relative 'active_record/project.rb'
require_relative 'active_record/task.rb'
require_relative 'active_record/code_type.rb'
require_relative 'active_record/code.rb'
require_relative 'active_record/task_code.rb'

include REXML


xmlfile = File.new( "../input/91.2711.xml" ) 
xmldoc = Document.new( xmlfile )

# Now get the root element
root = xmldoc.root
puts "Root element : " + root.attributes["type"]

# This will output all the movie titles.
xmldoc.elements.each("PRODUCTS/PRODUCT"){ 
   |e| puts "Title : " + e.attributes["name"] 
}

