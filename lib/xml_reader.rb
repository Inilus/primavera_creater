# force_encoding: utf-8
#
# File: xml_reader.rb

require 'rubygems'
require 'rexml/document'  # http://ruby.inuse.ru/article/obrabotka-xml-xpath-i-xsl-transformacii-v-ruby
require 'yaml'

include REXML

# загружаем файл environment.rb настройки и соединение с БД
require File.join( File.dirname(__FILE__), 'config/environment.rb' )

class Project < ActiveRecord::Base
    has_many :tasks
end

class Task < ActiveRecord::Base
    belongs_to :project
    has_many :codes, :through => :task_codes
end

class CodeType < ActiveRecord::Base
    has_many :codes   
end

class Code < ActiveRecord::Base
    belongs_to :code_type
    has_many :tasks, :through => :task_codes
end

class TaskCode < ActiveRecord::Base
    belongs_to :task
    belongs_to :code
end

xmlfile = File.new( "../input/91.2711.xml" ) 
xmldoc = Document.new( xmlfile )

# Now get the root element
root = xmldoc.root
puts "Root element : " + root.attributes["type"]

# This will output all the movie titles.
xmldoc.elements.each("PRODUCTS/PRODUCT"){ 
   |e| puts "Title : " + e.attributes["name"] 
}

