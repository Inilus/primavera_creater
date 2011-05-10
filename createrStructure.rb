# force_encoding: utf-8
#
# File: createrStructure.rb
#
# Docs for ProgressBar: http://0xcc.net/ruby-progressbar/index.html.en
# Docs for TinyTds: 		https://github.com/rails-sqlserver/tiny_tds#readme

require 'progressbar'
require 'tiny_tds'

class CreaterStructure
		attr_accessor :origin_data

		def initialize( config )
      @client = TinyTds::Client.new( :username => config[:db][:username], :password => config[:db][:password], :dataserver => config[:db][:dataserver] )

			@project 		 = nil
			@origin_data = nil
			@id_last_wbs = Array.new
			@short_name_project = nil

			@code_wbs 	 = config[:code][:wbs]
			@code_task 	 = config[:code][:task]
		end

		def load_data( project_name, count=-1, from="tbl_Structure3" )
			@client.execute( createSqlQuery( :use_temp ) ).do
			@origin_data = @client.execute( createSqlQuery( :select_all_from_tmp_table, { :count => count, :from => from, :project_name => project_name } ) ).each( :symbolize_keys => true )
			if @origin_data.empty?
				puts "Error! Don't find Project with name \"#{ project_name }\""
				exit( 1 )
			end		
			@short_name_project = project_name
			return @origin_data
		end

		def prepare_data
		  ## ProgressBar
		  pbar = ProgressBar.new( "Prepare data", @origin_data.size )

			## Iterator to all rows and search title project - field "id_parent" [1] == nil
			@origin_data.each_with_index do |row, index|
				if ( @project == nil ) and ( row[:id_parent] == -1 )
					@project = {
						:name 			=> row[:name].slice( 0, 200 ),
						:short_name => row[:name].slice( 0, 40 ),
						:id 				=> row[:id]
					}
					row[:description] = false
				else
				  row[:description] = true
					row[:level]       = row[:path].split( '\\' ).size-1
					row[:size_route]  = row[:route].split( '-' ).size
				end

			  ## ProgressBar
				pbar.inc
			end
			## ProgressBar
			pbar.finish
		end

		def save_data
			## ProgressBar
			pbar = ProgressBar.new( "Save in PMDB", @origin_data.size )

			unless @project.nil?
				## Create Project
				create_project

				## Iterator to all rows. Load data to Primavera
				@origin_data.each_with_index do |row, index|
					## If row with description task it's not project
					if row[:description]
						if row[:size_route] > 1
							## Split route and create tasks
							row[:route].reverse.split( '-' ).each_with_index do |route, index_step|
								create_task( row, route.reverse, true, ( row[:size_route] - index_step ) )
							end
						else
							create_task( row )
						end
					end
					## ProgressBar
					pbar.inc
				end
			else
				puts "\n\nError! Don't find configure project!"
				exit( 1 )
			end
			## ProgressBar
			pbar.finish
		end

		def get_project
			return @project
		end


	private

		def create_type_task_code( name, type="AS_Global" )
			data = @client.execute( createSqlQuery( :select_id_and_name_actv_type_code, { :name => name, :type => type } ) ).each( :as => :array )[0]
			if data == nil
				data = @client.execute( createSqlQuery( :select_id_new_actv_type_code ) ).each( :as => :array )[0]
				data[1] = name

				@client.execute(createSqlQuery( :insert_new_actv_type_code, { :name => name, :type => type } ) ).do
			end
			return Hash[ :id => data[0], :name_type => data[1] ]
		end

		def create_project
			@client.execute( createSqlQuery( :use_tempPmdb ) ).do
			# Select last id project & id wbs
			@project[:id_project] = @client.execute( createSqlQuery( :select_id_new_project ) ).each( :symbolize_keys => true )[0][:key_seq_num]
			@project[:id_project_wbs] = @id_last_wbs[0] = @client.execute( createSqlQuery( :select_id_new_projwbs ) ).each( :symbolize_keys => true )[0][:key_seq_num]

			@client.execute( createSqlQuery( :insert_new_project_and_projwbs ) )

		  ## Global task code
		  @project[:task_code_type] = Hash.new
			## Global task code Product
			@project[:task_code_type][:product]     = create_type_task_code( "Product" )
			## Global task code Route
			@project[:task_code_type][:route]       = create_type_task_code( "Route" )
			## Global task code Step route
			@project[:task_code_type][:step_route]  = create_type_task_code( "Step route" )
			## Global task code Route full
			@project[:task_code_type][:route_full]  = create_type_task_code( "Route full" )
			## Global task code DO
			@project[:task_code_type][:do]          = create_type_task_code( "DO" )
			## Global task code Material
			@project[:task_code_type][:material]    = create_type_task_code( "Material" )
		end

		def create_task( row, route=nil, relationship_self=false, step=1 )
		  ## Search parent task in origin_data
			id_parent = @origin_data.select { |r| r[:id] == row[:id_parent] }
			id_parent = ( ( not id_parent.empty? ) and ( id_parent[0][:description] ) and ( id_parent[0].include?( :id_task ) ) ) ? id_parent[0][:id_task].to_s : @project[:id_project_wbs]
			## If not root level, search id parent task
			if ( ( row[:id_parent] != @project[:id] ) or relationship_self ) and row.include?(:id_task)
				id_parent = row[:id_task].to_s
			end

			## Select last id task
			row[:id_task] = @client.execute( createSqlQuery( :select_id_new_task ) ).each( :symbolize_keys => true )[0][:key_seq_num]

			@client.execute( createSqlQuery( :insert_new_task, { :name_row => row[:name] } ) ).do

			## Create global task code
			## Global task code Product
			@project[:task_code_type][:product][:lost] = create_task_code( row[:id_task], @project[:task_code_type][:product], row[:name] )
			## Global task code Route
			@project[:task_code_type][:route][:lost] = create_task_code( row[:id_task], @project[:task_code_type][:route], ( ( route == nil ) ? row[:route].to_s : route.to_s ) )
			## Global task code Step route
			@project[:task_code_type][:step_route][:lost] = create_task_code( row[:id_task], @project[:task_code_type][:step_route], step.to_s, "", false )
			## Global task code Route_full
			@project[:task_code_type][:route_full][:lost] = create_task_code( row[:id_task], @project[:task_code_type][:route_full], row[:route] )
			## Global task code DO
			@project[:task_code_type][:do][:lost] = create_task_code( row[:id_task], @project[:task_code_type][:do], ( row[:do].empty? ? "none" : row[:do] ), row[:name] )
			## Global task code Material
			@project[:task_code_type][:material][:lost] = create_task_code( row[:id_task], @project[:task_code_type][:material], ( row[:material].empty? ? "none" : row[:material] ) )


			## Create user fields
			## QTY ( ID=603 )
			@client.execute( createSqlQuery( :insert_new_uf_qty, { :row => row } ) ).do
			## Weight (ID=604)
			@client.execute( createSqlQuery( :insert_new_uf_weight, { :row => row } ) ).do

			## Create relationship
			## If not root level
			if id_parent != @project[:id_project_wbs]
				@client.execute( createSqlQuery( :insert_relationship, { :id_parent => id_parent, :row => row } ) ).do
			end
		end

		def create_task_code( id_task, task_code_type, value, long_value="", cached=true )
			if cached and ( task_code_type.include?( :lost ) and task_code_type[:lost].include?(:value) and	task_code_type[:lost][:value] == value )
				lost = task_code_type[:lost]
			else
			  lost = Hash.new
				lost[:value] = value
				if task_code_type.include?( :num_lost )
					lost[:num_lost] += 1
				else
					lost[:num_lost] = 0
				end

				lost[:id] = @client.execute( createSqlQuery( :select_id_and_short_name_actv_code, { :id_task_code_type => task_code_type[:id], :value => value } ) ).each( :symbolize_keys => true )
				## If code does't exist, create code
				if not lost[:id].empty?
          lost[:id] = lost[:id][0][:actv_code_id]
        else
					## Select id last task code
					lost[:id] = @client.execute( createSqlQuery( :select_id_new_actv_code ) ).each( :symbolize_keys => true )[0][:key_seq_num]
          long_value = value if long_value.empty?
					@client.execute( createSqlQuery( :insert_new_actv_code, { :id_task_code_type => task_code_type[:id], :num_lost => lost[:num_lost], :value => value, :long_value => long_value } ) ).do
				end
			end

			@client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => id_task, :id_task_code_type => task_code_type[:id], :id_lost => lost[:id] } ) ).do

			return lost
		end



#		def insert_date_create( from="tbl_Structure3" )
#			@client.execute( createSqlQuery( :use_temp ) ).do

#			date = Time.now.to_i
#			@origin_data.each_with_index do |row, index|
#				@client.execute( "UPDATE [#{ from.to_s }] SET [date_create] = #{ date } WHERE " ).do
#			end
#		end




		def createSqlQuery( name_query, params={} )
		  case name_query

		    ## def load_data
		    when :use_temp
		    	## Required: params{ }
		    	return "use Temp; "
		    when :select_all_from_tmp_table
		    	## Required: params{ :count, :from, :project_name }
		    	return "SELECT #{ ( ( params[:count] > -1 ) ? ( 'TOP ' + params[:count].to_s + ' ' ) : '' ) } * FROM #{ params[:from] } WHERE [project] LIKE '#{ params[:project_name] }'; "

		    ## def create_type_task_code
		    when :select_id_and_name_actv_type_code
		    	## Required: params{ :name, :type }
		    	return "SELECT TOP 1 actv_code_type_id, actv_code_type FROM [dbo].[ACTVTYPE] WHERE [actv_code_type]='#{ params[:name] }' AND [actv_code_type_scope]='#{ params[:type] }';"
				when :select_id_new_actv_type_code
					## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='actvtype_actv_code_type_id';"
		    when :insert_new_actv_type_code
		    	## Required: params{ :name, :type }
		    	return "DECLARE @id_type_code int, @pseq_num int;
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'actvtype_actv_code_type_id', @pseq_num = @pseq_num OUTPUT;
set @id_type_code = @pseq_num;
INSERT INTO [dbo].[ACTVTYPE] ([actv_code_type_id], [actv_short_len], [seq_num], [actv_code_type], [actv_code_type_scope], [super_flag]) VALUES ( @id_type_code, 60, 0, '#{ params[:name] }', '#{ params[:type] }', 'N' ); "

		    ## def create_project
		    when :use_tempPmdb
		    	## Required: params{ }
		    	return "use TempPMDB; "
		    when :select_id_new_project
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM NEXTKEY WHERE key_name='project_proj_id'; "
				when :select_id_new_projwbs
					## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='projwbs_wbs_id'; "
		    when :insert_new_project_and_projwbs
		    	## Required: params{ }
		    	return "DECLARE @id_project int, @id_projwbs int, @pseq_num int, @GUID_project varchar(22), @GUID_projwbs varchar(22), @EncGUID varchar(22);
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'project_proj_id', @pseq_num = @pseq_num OUTPUT;
set @id_project = @pseq_num;
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'projwbs_wbs_id', @pseq_num = @pseq_num OUTPUT;
set @id_projwbs = @pseq_num;
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
set @GUID_project = @EncGUID;
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
set @GUID_projwbs = @EncGUID;
INSERT INTO [dbo].[PROJECT] ([proj_id], [fy_start_month_num], [allow_complete_flag], [project_flag], [name_sep_char], [proj_short_name], [clndr_id], [plan_start_date], [guid]) VALUES ( @id_project, 1, 'Y', 'Y', '.', '#{ @short_name_project }', 1408, 0, @GUID_project );
INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [ev_compute_type], [ev_etc_compute_type], [guid]) VALUES (@id_projwbs, @id_project, 565, 100, 1.00, 'Y', 'WS_Open', '#{ @short_name_project }', '#{ @project[:name] }', 6366, 6, 0.88, 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs); "

		    ## def create_task
		    when :select_id_new_task
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='task_task_id';"
		    when :insert_new_task
		    	## Required: params{ :name_row }
		    	return "DECLARE @id_task int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22);
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'task_task_id', @pseq_num = @pseq_num OUTPUT;
set @id_task = @pseq_num;
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
set @GUID_task = @EncGUID;
INSERT INTO [dbo].[TASK]
( [task_id], [proj_id], [wbs_id], [clndr_id], [est_wt], [complete_pct_type], [task_type], [duration_type], [review_type], [status_code], [task_code], [task_name], [remain_drtn_hr_cnt], [target_drtn_hr_cnt], [late_start_date], [late_end_date], [cstr_type], [guid])
VALUES (@id_task, #{ @project[:id_project] }, #{ @project[:id_project_wbs] }, 1408, 1.0, 'CP_Drtn', 'TT_Task', 'DT_FixedRate', 'RV_OK', 'TK_NotStart', '#{ @code_task.next! }', '#{ params[:name_row].slice( 0, 300 ) }', 24, 24, null, null, 'CS_ALAP', @GUID_task)"
		    when :insert_new_uf_qty
		    	## Required: params{ :row }
		    	return "INSERT INTO [dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_number])
VALUES ( 603, #{ params[:row][:id_task] }, #{ @project[:id_project] }, #{ params[:row][:qty] } ); "
		    when :insert_new_uf_weight
		    	## Required: params{ :row }
		    	return "INSERT INTO [dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_text])
VALUES ( 604, #{ params[:row][:id_task] }, #{ @project[:id_project] }, '#{ params[:row][:weight] }'); "
		    when :insert_relationship
		    	## Required: params{ :id_parent, :row }
		    	return  "DECLARE @id_relationship int, @pseq_num int;
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT;
set @id_relationship = @pseq_num;
INSERT INTO [dbo].[TASKPRED] ( [task_pred_id], [task_id], [pred_task_id], [proj_id], [pred_proj_id], [pred_type] )
VALUES ( @id_relationship, #{ params[:id_parent] }, #{ params[:row][:id_task] }, #{ @project[:id_project] }, #{ @project[:id_project] }, 'PR_FS' ); "

		    ## def create_task_code
		    when :select_id_and_short_name_actv_code
		    	## Required: params{ :id_task_code_type, :value }
		    	return "SELECT TOP 1 actv_code_id, short_name FROM [dbo].[ACTVCODE] WHERE [actv_code_type_id]=#{ params[:id_task_code_type] } AND [actv_code_name]='#{ params[:value] }'; "
		    when :select_id_new_actv_code
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='actvcode_actv_code_id'; "
		    when :insert_new_actv_code
		    	## Required: params{ :id_task_code_type, :num_lost, :long_value, :value }
		    	return "DECLARE @id_code int, @pseq_num int;
EXEC [dbo].[pc_get_next_key] @pkey_name = 'actvcode_actv_code_id', @pseq_num = @pseq_num OUTPUT;
set @id_code = @pseq_num;
INSERT INTO [dbo].[ACTVCODE] ( [actv_code_id], [actv_code_type_id], [seq_num], [short_name], [actv_code_name] )
VALUES ( @id_code, #{ params[:id_task_code_type] }, #{ params[:num_lost] }, '#{ params[:value].slice(0,60) }', '#{ params[:long_value] }' ); "
		    when :insert_new_relationship_actv_code_with_task
		    	## Required: params{ :id_task, :id_task_code_type, :id_lost }
		    	return "INSERT INTO [dbo].[TASKACTV]
([task_id], [actv_code_type_id], [actv_code_id], [proj_id])
VALUES (#{ params[:id_task] }, #{ params[:id_task_code_type] }, #{ params[:id_lost] }, #{ @project[:id_project] })"

		    else
		    	return nil
		  end
	end

end

