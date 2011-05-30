# force_encoding: utf-8
#
# File: get_project.rb

require 'nokogiri'    # http://nokogiri.org/
require 'open-uri'

class GetProject

  def initialize ( xml_file_name, config )
    if @project.nil? or update
      @xmldoc = Nokogiri::XML( File.open( xml_file_name ) )

      @code_task = config[:code][:task]

      @project = Project.create
      @project.start_date = 0
      @project.project_type = @xmldoc.xpath( "//PRODUCTS" ).attribute("type").value
      @project.save

      @tasks = nil

      load_project
    end
  end

  def get_project
    @project
  end

  private

    def load_project
      ## ProgressBar
		  pbar = ProgressBar.new( "Prepare data", @xmldoc.xpath( "//PRODUCTS/PRODUCT" ).size )

      @xmldoc.xpath( "//PRODUCTS/PRODUCT" ).each_with_index do |product, index|
        unless product.attribute( "structure" ).value.empty?
          basic_task = Task.new
          basic_task.name         = product.attribute( "name" ).value
          basic_task.id_1c        = product.attribute( "id" ).value.to_i
          basic_task.parent_id_1c = product.attribute( "id_parent" ).value.to_i
          basic_task.qty          = product.attribute( "qty" ).nil? ? 0 : product.attribute( "qty" ).value

          if basic_task.parent_id_1c.to_i == -1
            @tasks = @project.tasks
            if @project.name.nil?
              @project.name       = product.attribute( "name" ).value
              @project.short_name = product.attribute( "do" ).value
              @project.save
            end
          else
            tmp = @project.tasks.find_last_by_id_1c( basic_task.parent_id_1c )
            @tasks = ( not tmp.nil? ) ? tmp.tasks : @project.tasks
          end

          basic_task.project_id       = @project.id
          basic_task.material_weight  = 0

          codes = Hash.new
          codes[:structure]   = CodeType.
              find_or_create_by_name( "Structure" ).
              codes.
              find_or_create_by_short_name( product.attribute( "structure" ).value  )
          codes[:product]     = CodeType.
              find_or_create_by_name( "Product" ).
              codes.
              find_or_create_by_short_name_and_name( basic_task.id_1c, basic_task.name )
          codes[:do]          = CodeType.
              find_or_create_by_name( "DO" ).
              codes.
              find_or_create_by_short_name_and_name( product.attribute( "do" ).value, basic_task.name )
          codes[:plot]        = CodeType.
              find_or_create_by_name( "Plot" ).
              codes.
              find_or_create_by_short_name_and_name( product.attribute( "plot" ).value, basic_task.name )
          codes[:route_full]  = CodeType.
              find_or_create_by_name( "Route full" ).
              codes.
              find_or_create_by_short_name( product.attribute( "route_full" ).value )

          material = product.xpath( "MATERIAL" )
          unless material.empty?
            codes[:material]  = CodeType.
                find_or_create_by_name( "Material" ).
                codes.
                find_or_create_by_short_name_and_name(
                  material.attribute( "id" ).value, material.attribute( "name" ).value )

            basic_task.material_weight = material.attribute( "weight" ).
                value.gsub( ",", "." ) unless material.attribute( "weight" ).nil?
          end

          tasks = @tasks

          product.xpath("ROUTES/ROUTE").reverse.each do |route|
            if ["1", "2", "3", "4", "5", "7", "8", "11", "12", "14", "16", "25", "26", "30", "33", "35", "143", "168"]
                  .include? route.attribute( "code" ).value
              task = tasks.create
              tasks = task.tasks

              task.project_id       = basic_task.project_id
              task.short_name       = @code_task.next!
              task.name             = basic_task.name
              task.id_1c            = basic_task.id_1c
              task.parent_id_1c     = basic_task.parent_id_1c
              task.qty              = basic_task.qty
              task.material_weight  = basic_task.material_weight

              task.duration         = ( not route.attribute( "duration" ).nil? ) ?
                                            route.attribute( "duration" ).value.
                                              gsub( ",", "." ).
                                              gsub( " ", "" ).to_f.ceil : 0
              task.labor_units      = ( not route.attribute( "labor_units" ).nil? ) ?
                                            route.attribute( "labor_units" ).value.
                                              gsub( ",", "." ).
                                              gsub( " ", "" ) : 0
#              task.num_operations   = ( not route.attribute( "num_operations" ).nil? ) ?
#                                            route.attribute( "num_operations" ).value : "none"
## TODO replace labor_units_shrm to labor_units_nums
#              task.labor_units_nums = ( not route.attribute( "labor_units_shrm" ).nil? ) ?
#                                            route.attribute( "labor_units_shrm" ).value : "none"

              task.codes << codes[:structure]
              task.codes << codes[:product]    unless codes[:product].nil?
              task.codes << codes[:do]         unless codes[:do].nil?
              task.codes << codes[:plot]       unless codes[:plot].nil?
              task.codes << codes[:material]   unless codes[:material].nil?
              task.codes << codes[:route_full] unless codes[:route_full].nil?

              ## Step route
              num = route.attribute( "num" ).value.to_i
              num = "0#{ num }" if ( num < 10 )
              task.codes << CodeType.
                  find_or_create_by_name( "Step route" ).
                  codes.
                  find_or_create_by_short_name( num.to_s, num.to_s )

              ## Route
              # Using only route#code without route#name
              name = route.attribute( "code" ).value.to_i
#              name = route.attribute( "name" ).value
              name = "0#{ name }" if ( name < 10 )
              task.codes << CodeType.
                  find_or_create_by_name( "Route" ).
                  codes.
                  find_or_create_by_short_name( name, name )

              ## SHRM
#              shrm = ( not route.attribute( "shrm" ).nil? ) ?
#                  route.attribute( "shrm" ).value : nil
#              task.codes << CodeType.
#                  find_or_create_by_name( "SHRM" ).
#                  codes.
#                  find_or_create_by_short_name( shrm, shrm )

              ## Num operations
              route.xpath("OPERATIONS/OPERATION").each do |operation|
                task.num_operations += "-" unless task.num_operations.empty?
                task.num_operations += operation.attribute( "num" ).value
              end
              task.num_operations = "none" if task.num_operations.empty?

              task.save
            end
          end

          ## ProgressBar
				  pbar.inc
#################################
#          break if index == 30
#################################
        end
      end

      ## ProgressBar
			pbar.finish

			@project.save
    end

end

