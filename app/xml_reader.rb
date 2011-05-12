#!/usr/bin/env ruby
#
# force_encoding: utf-8
#
# File: xml_reader.rb

require 'rubygems'
require 'nokogiri'    # http://nokogiri.org/
require 'open-uri'
require 'yaml'        # http://santoro.tk/mirror/ruby-core/classes/YAML.html

require_relative 'environment.rb'

require_relative 'active_record/project.rb'
require_relative 'active_record/task.rb'
require_relative 'active_record/code_type.rb'
require_relative 'active_record/code.rb'
require_relative 'active_record/task_code.rb'


@xmldoc = Nokogiri::XML( File.open( "input/91.2711-dev.xml" ) )

config = YAML.load_file( "config/application.yml" )
@code_task = config[:code][:task]

@project = Project.create

@project.start_date = 0
@project.type = @xmldoc.xpath( "//PRODUCTS" ).attribute("type").value
@tasks = nil

@xmldoc.xpath( "//PRODUCTS/PRODUCT" ).each_with_index do |product, index|
 
  if @project.name.nil? and 
      ( product.attribute( "id_parent" ).value.to_i == -1 )
    @project.name       = product.attribute( "name" ).value
    @project.short_name = product.attribute( "do" ).value    
    @project.save
    
    @tasks = @project.tasks
  else
    @tasks = @project.tasks.find_last_by_id_1c( product.attribute( "id_parent" ).value ).tasks
  end

  basic_task = Task.new
  basic_task.project_id       = @project.id
  basic_task.name             = product.attribute( "name" ).value
  basic_task.id_1c            = product.attribute( "id" ).value
  basic_task.parent_id_1c     = product.attribute( "id_parent" ).value  
  basic_task.material_qty     = 0
  basic_task.material_weight  = 0
  
  codes = Hash.new
  codes[:structure] = CodeType.find_or_create_by_name( "Structure" ).codes.find_or_create_by_short_name( product.attribute( "structure" ).value  )
  codes[:product] = CodeType.find_or_create_by_name( "Product" ).codes.find_or_create_by_short_name( basic_task.id_1c, basic_task.name )
  codes[:do] = CodeType.find_or_create_by_name( "DO" ).codes.find_or_create_by_short_name( product.attribute( "do" ).value, basic_task.name )
  codes[:plot] = CodeType.find_or_create_by_name( "Plot" ).codes.find_or_create_by_short_name( product.attribute( "plot" ).value, basic_task.name )
  
  material = product.xpath( "MATERIAL" )
  unless material.empty?  
    codes[:material] = CodeType.find_or_create_by_name( "Material" ).codes.find_or_create_by_short_name( material.attribute( "id" ).value, material.attribute( "name" ).value )
    
    basic_task.material_qty = material.attribute( "qty" ).value unless material.attribute( "qty" ).nil?
    basic_task.material_weight = material.attribute( "weight" ).value.gsub( ",", "." ) unless material.attribute( "weight" ).nil?    
  end
    
  tasks = @tasks
  
  product.xpath("ROUTES/ROUTE").each_with_index do |route, index|        
    task = tasks.create
    tasks = task.tasks
    
    task.project_id       = basic_task.project_id
    task.short_name       = @code_task.next!
    task.name             = basic_task.name    
    task.id_1c            = basic_task.id_1c
    task.parent_id_1c     = basic_task.parent_id_1c
    task.material_qty     = basic_task.material_qty
    task.material_weight  = basic_task.material_weight

    task.duration         = ( not route.attribute( "duration" ).nil? ) ? route.attribute( "duration" ).value : 0
    task.labor_units      = ( not route.attribute( "labor_units" ).nil? ) ? route.attribute( "labor_units" ).value : 0
    
    task.codes << codes[:structure]  unless codes[:structure].nil?
    task.codes << codes[:product]    unless codes[:product].nil?
    task.codes << codes[:do]         unless codes[:do].nil?
    task.codes << codes[:plot]       unless codes[:plot].nil?
    task.codes << codes[:material]   unless codes[:material].nil?
    
    task.codes << CodeType.find_or_create_by_name( "Step route" ).codes.find_or_create_by_short_name( route.attribute( "num" ).value, route.attribute( "num" ).value )
    task.codes << CodeType.find_or_create_by_name( "Route" ).codes.find_or_create_by_short_name( route.attribute( "name" ).value, route.attribute( "name" ).value )
    task.codes << CodeType.find_or_create_by_name( "SHRM" ).codes.find_or_create_by_short_name( ( not route.attribute( "shrm" ).nil? ) ? route.attribute( "shrm" ).value : nil, ( not route.attribute( "shrm" ).nil? ) ? route.attribute( "shrm" ).value : nil )
    
    task.save
    
  end
    
  break if index == 2
end



#p @project.inspect
