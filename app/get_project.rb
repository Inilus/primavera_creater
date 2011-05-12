# force_encoding: utf-8
#
# File: get_project.rb

require 'nokogiri'    # http://nokogiri.org/
require 'open-uri'

class GetProject

  def initialize ( project_short_name, xml_file_name, config, update=false )       
    @project = Project.find_by_short_name( project_short_name )
    if @project.nil? or update
      @xmldoc = Nokogiri::XML( File.open( xml_file_name ) )
    
      @code_task = config[:code][:task]
      
      # If update project, then remove old variant
      if update
        Project.delete( @project )
        @project.tasks.delete
      end
    
      @project = Project.create
      @project.start_date = 0
      @project.project_type = @xmldoc.xpath( "//PRODUCTS" ).attribute("type").value
      @project.save
      
      @tasks = nil
      
      create_project    
    end        
  end
  
  def get_project
    @project
  end  

  private
  
    def create_project
      ## ProgressBar
		  pbar = ProgressBar.new( "Prepare data", @xmldoc.xpath( "//PRODUCTS/PRODUCT" ).size )		  
      
      @xmldoc.xpath( "//PRODUCTS/PRODUCT" ).each_with_index do |product, index|
        unless product.attribute( "structure" ).value.empty?
          basic_task = Task.new
          basic_task.name             = product.attribute( "name" ).value
          basic_task.id_1c            = product.attribute( "id" ).value
          basic_task.parent_id_1c     = product.attribute( "id_parent" ).value  
           
          if basic_task.parent_id_1c.to_i == -1
            @tasks = @project.tasks
            if @project.name.nil?
              @project.name       = product.attribute( "name" ).value
              @project.short_name = product.attribute( "do" ).value    
              @project.save      
            end   
          else
            tmp = @project.tasks.find_last_by_id_1c( basic_task.parent_id_1c )
#            p tmp.inspect
            @tasks = ( not tmp.nil? ) ? tmp.tasks : @project.tasks
          end
            
          basic_task.project_id       = @project.id
          basic_task.material_qty     = 0
          basic_task.material_weight  = 0
          
          codes = Hash.new
          codes[:structure] = CodeType.find_or_create_by_name( "Structure" ).codes.find_or_create_by_short_name( product.attribute( "structure" ).value  )
          codes[:product] = CodeType.find_or_create_by_name( "Product" ).codes.find_or_create_by_short_name_and_name( basic_task.id_1c, basic_task.name )
          codes[:do] = CodeType.find_or_create_by_name( "DO" ).codes.find_or_create_by_short_name_and_name( product.attribute( "do" ).value, basic_task.name )
          codes[:plot] = CodeType.find_or_create_by_name( "Plot" ).codes.find_or_create_by_short_name_and_name( product.attribute( "plot" ).value, basic_task.name )
          codes[:route_full] = CodeType.find_or_create_by_name( "Route full" ).codes.find_or_create_by_short_name( product.attribute( "route_full" ).value )
          
          material = product.xpath( "MATERIAL" )
          unless material.empty?  
            codes[:material] = CodeType.find_or_create_by_name( "Material" ).codes.find_or_create_by_short_name_and_name( material.attribute( "id" ).value, material.attribute( "name" ).value )
            
            basic_task.material_qty = material.attribute( "qty" ).value unless material.attribute( "qty" ).nil?
            basic_task.material_weight = material.attribute( "weight" ).value.gsub( ",", "." ) unless material.attribute( "weight" ).nil?    
          end
            
          tasks = @tasks
          
          product.xpath("ROUTES/ROUTE").each do |route|
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
            task.num_operations   = ( not route.attribute( "num_operations" ).nil? ) ? route.attribute( "num_operations" ).value : "none"
  #          task.labor_units_shrm   = ( not route.attribute( "labor_units_shrm" ).nil? ) ? route.attribute( "labor_units_shrm" ).value : 0
            
            task.codes << codes[:structure]  unless codes[:structure].nil?
            task.codes << codes[:product]    unless codes[:product].nil?
            task.codes << codes[:do]         unless codes[:do].nil?
            task.codes << codes[:plot]       unless codes[:plot].nil?
            task.codes << codes[:material]   unless codes[:material].nil?
            task.codes << codes[:route_full] unless codes[:route_full].nil?
            
            task.codes << CodeType.find_or_create_by_name( "Step route" ).codes.find_or_create_by_short_name( route.attribute( "num" ).value, route.attribute( "num" ).value )
            task.codes << CodeType.find_or_create_by_name( "Route" ).codes.find_or_create_by_short_name( route.attribute( "name" ).value, route.attribute( "name" ).value )
            task.codes << CodeType.find_or_create_by_name( "SHRM" ).codes.find_or_create_by_short_name( ( not route.attribute( "shrm" ).nil? ) ? route.attribute( "shrm" ).value : nil, ( not route.attribute( "shrm" ).nil? ) ? route.attribute( "shrm" ).value : nil )
            
            task.save                    
          end
            
          ## ProgressBar
				  pbar.inc
				
  #        break if index == 1
        end
      end

      ## ProgressBar
			pbar.finish
			
			@project.save
    end

end
