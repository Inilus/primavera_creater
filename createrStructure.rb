# force_encoding: utf-8
#
# File: createrStructure.rb

require 'progressbar'
require_relative 'sqlServerConnector'

class CreaterStructure
		attr_accessor :origin_data
	
		def initialize
			@project 		 = nil		
			@id_last_wbs = Array.new
			@code_wbs 	 = "000000"
			@code_task 	 = "A00000"			
			@origin_data = nil
		
			@db_pmdb = create_connection_string( "tempPMDB" )									
		end		
		
		def load_data( count=-1, from="tbl_Structure3" )
			db_structure = create_connection_string( "Temp" )
			return @origin_data = db_structure.query( "SELECT " + ( ( count > -1 ) ? "TOP " + count.to_s + " " : "" ) + "* FROM #{from}" )
		end

		def prepare_data
			## Iterator to all rows and search title project - field "id_parent" [1] == nil
			pbar = ProgressBar.new( "Prepare data", @origin_data.size )
				
			@origin_data.each_index do |index_row|
				if ( @project == nil ) and ( @origin_data[index_row][1] == -1 )
					@project = { 
						:name 			=> @origin_data[index_row][2].slice( 0, 200 ),
						:short_name => @origin_data[index_row][2].slice( 0, 40 ),
						:id 				=> @origin_data[index_row][0]
					}
				else
					@origin_data[index_row][10] = Hash[ :level => ( @origin_data[index_row][3].split('\\' ).size-1 ), :size_route => @origin_data[index_row][4].split( '-' ).size ] 
				end		
			
				pbar.inc
			end		
			pbar.finish
		end

		def save_data
			## ProgressBar
			pbar = ProgressBar.new( "Save in PMDB", @origin_data.size )
		
			unless @project.empty?							
				## Create Project
				create_project		
			
				## Iterator to all rows. Load data to Primavera			
				@origin_data.each_index do |index_row|
					## If row with description task, not project
					if @origin_data[index_row][10] != nil			
						if @origin_data[index_row][10][:size_route] > 1
							## Split route and create tasks
							@origin_data[index_row][4].reverse.split('-').each_with_index do |route, index|		
								create_task(index_row, route.reverse, true, ( @origin_data[index_row][10][:size_route] - index ) )
							end				
						else					
							create_task(index_row)
						end
					end
					pbar.inc
				end						
			else
				puts "Don't have config for project!"
			end		
			pbar.finish		
		end

		def get_project
			return @project
		end
		

	private
		def create_connection_string( db_name )
			conn_string_to_db =  "Provider=SQLOLEDB.1;"
			conn_string_to_db << "Persist Security Info=False;"
			conn_string_to_db << "User ID=privuser;"
			conn_string_to_db << "password=privuser;"
			conn_string_to_db << "Initial Catalog=#{db_name};"
			conn_string_to_db << "Data Source=10.10.2.31;"
			conn_string_to_db << "Network Library=dbmssocn"
			return SqlServerConnector.new( conn_string_to_db )
		end

		def search_wbs_up_level( level )
			# Search id uplevel wbs
			while @id_last_wbs[level] == nil
				level -= 1
			end
			return level
		end

		def create_type_task_code( name, type="AS_Global" )
			data = @db_pmdb.query( "SELECT TOP 1 actv_code_type_id, actv_code_type FROM [dbo].[ACTVTYPE] WHERE [actv_code_type]='#{name}' AND [actv_code_type_scope]='#{type}';" )	
			if data.empty?
				# Select id last type task code route_full
				data = @db_pmdb.query( "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='actvtype_actv_code_type_id';" )
					
				@db_pmdb.exec( "DECLARE @id_type_code int, @pseq_num int
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'actvtype_actv_code_type_id', @pseq_num = @pseq_num OUTPUT
set @id_type_code = @pseq_num
INSERT INTO [dbo].[ACTVTYPE] 
([actv_code_type_id], [actv_short_len], [seq_num], [actv_code_type], [actv_code_type_scope], [super_flag])
VALUES ( @id_type_code, 60, 0, '#{name}', '#{type}', 'N' )" )	
			end
			return Hash[ :id => data[0][0], :id_type => data[0][1] ]	
		end

		def create_project
			# Select last id project & id wbs			
			@project[:id_project] = @db_pmdb.query( "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='project_proj_id';" )[0][0]					
			@project[:id_project_wbs] = @id_last_wbs[0] = @db_pmdb.query( "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='projwbs_wbs_id';" )[0][0]	
			
			@db_pmdb.exec( "DECLARE @id_project int, @id_projwbs int, @pseq_num int, @GUID_project varchar(22), @GUID_projwbs varchar(22), @EncGUID varchar(22)
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'project_proj_id', @pseq_num = @pseq_num OUTPUT
set @id_project = @pseq_num
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'projwbs_wbs_id', @pseq_num = @pseq_num OUTPUT
set @id_projwbs = @pseq_num
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
set @GUID_project = @EncGUID
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
set @GUID_projwbs = @EncGUID
INSERT INTO [dbo].[PROJECT] ([proj_id], [fy_start_month_num], [allow_complete_flag], [project_flag], [name_sep_char], [proj_short_name], [clndr_id], [plan_start_date], [guid]) 
VALUES (@id_project, 1, 'Y', 'Y', '.', '#{@project[:short_name]}', 1408, 0, @GUID_project)
INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [ev_compute_type], [ev_etc_compute_type], [guid]) 
VALUES (@id_projwbs, @id_project, 565, 100, 1.00, 'Y', 'WS_Open', '#{@project[:short_name]}', '#{@project[:name]}', 6366, 6, 0.88, 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs)" )
		
			## Global task code Product 
			@project[:task_code_type_product] = create_type_task_code( "Product" )
			## Global task code Route 
			@project[:task_code_type_route] = create_type_task_code( "Route" )
			## Global task code Step route
			@project[:task_code_type_step_route] = create_type_task_code( "Step route" )
			## Global task code Route full 	
			@project[:task_code_type_route_full] = create_type_task_code( "Route full" )	
			## Global task code DO 
			@project[:task_code_type_do] = create_type_task_code( "DO" )
			## Global task code Material 
			@project[:task_code_type_material] = create_type_task_code( "Material" )
		end

		def create_wbs( index_row )
			# Select last id wbs				
			level = @origin_data[index_row][10][:level]	
			@id_last_wbs[level] = @db_pmdb.query( "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='projwbs_wbs_id';" )[0][0]	
			
			# Clear id_last_wbs for down levels
			if @id_last_wbs.size > ( level + 1 )		
				@id_last_wbs = @id_last_wbs.values_at( 0..level )	
			end
		
			# Search id uplevel wbs
			level = search_wbs_up_level(level - 1)	
		
			@db_pmdb.exec( "DECLARE @id_projwbs int, @pseq_num int, @GUID_projwbs varchar(22), @EncGUID varchar(22)			
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'projwbs_wbs_id', @pseq_num = @pseq_num OUTPUT
set @id_projwbs = @pseq_num
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
set @GUID_projwbs = @EncGUID			
INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [dscnt_period_type], [ev_compute_type], [ev_etc_compute_type], [guid]) 
VALUES (@id_projwbs, #{@project[:id_project]}, 565, 10, 1.00, 'N', 'WS_Open', '#{@code_wbs.next!}', '#{@origin_data[index_row][2].slice(0, 300)}', #{@id_last_wbs[level]}, 6, 0.88, 'Month', 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs)" )	
		end

		def create_task_code( id_task, task_code_type, value, cached=true )
			if cached and ( task_code_type.include?(:lost) and task_code_type[:lost].include?(:value) and	task_code_type[:lost]["value"] == value )
				lost = task_code_type[:lost]
			else	
				lost = Hash.new		
				lost[:value] = value	
				if task_code_type.include?( :num_lost )
					lost[:num_lost] += 1
				else
					lost[:num_lost] = 0 					
				end								

				data = @db_pmdb.query("SELECT TOP 1 [actv_code_id], [short_name], [actv_code_name] FROM [dbo].[ACTVCODE] WHERE [actv_code_type_id]=#{task_code_type[:id]} AND [actv_code_name]='#{value}';")
				if data.empty?
					## Select id last task code
					data = @db_pmdb.query( "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='actvcode_actv_code_id';" )
				
					@db_pmdb.exec( "DECLARE @id_code int, @pseq_num int
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'actvcode_actv_code_id', @pseq_num = @pseq_num OUTPUT
set @id_code = @pseq_num
INSERT INTO [dbo].[ACTVCODE] ( [actv_code_id], [actv_code_type_id], [seq_num], [short_name], [actv_code_name] )
VALUES ( @id_code, #{task_code_type[:id]}, #{lost[:num_lost]}, '#{value.slice(0,60)}', '#{value}' )" )	
				end
				
				lost[:id] = data[0][0]				
			end	
		
			@db_pmdb.exec( "INSERT INTO [dbo].[TASKACTV] 
	([task_id], [actv_code_type_id], [actv_code_id], [proj_id])
	VALUES (#{id_task}, #{task_code_type[:id]}, #{lost[:id]}, #{@project[:id_project]})" )			
		
			return lost
		end		

		def create_task( index_row, route=nil, relationship_self=false, step=1 )
			id_parent = @origin_data.select { |row| row[0] == @origin_data[index_row][1] }
			id_parent = ( ( not id_parent.empty? ) and ( id_parent[0][10] != nil ) and ( id_parent[0][10].include?( :id_task ) ) ) ? id_parent[0][10][:id_task].to_s : @project[:id_project_wbs]
			## If not root level, search id parent task
			if ( ( @origin_data[index_row][1] != @project[:id] ) or relationship_self ) and @origin_data[index_row][10].include?(:id_task)
				id_parent = @origin_data[index_row][10][:id_task].to_s		
			end
		
			## Select last id task				
			@origin_data[index_row][10][:id_task] = @db_pmdb.query( "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='task_task_id';" )[0][0]
					
			@db_pmdb.exec( "DECLARE @id_task int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22)
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'task_task_id', @pseq_num = @pseq_num OUTPUT
set @id_task = @pseq_num
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
set @GUID_task = @EncGUID
INSERT INTO [dbo].[TASK] 
( [task_id], [proj_id], [wbs_id], [clndr_id], [est_wt], [complete_pct_type], [task_type], [duration_type], [review_type], [status_code], [task_code], [task_name], [remain_drtn_hr_cnt], [target_drtn_hr_cnt], [late_start_date], [late_end_date], [cstr_type], [guid])
VALUES 
(@id_task, #{@project[:id_project]}, #{@project[:id_project_wbs]}, 1408, 1.0, 'CP_Drtn', 'TT_Task', 'DT_FixedRate', 'RV_OK', 'TK_NotStart', '#{@code_task.next!}', '#{@origin_data[index_row][2].slice(0, 300)}', 168, 168, null, null, 'CS_ALAP', @GUID_task)" )
		
			## Create global task code
			## Global task code Product
			@project[:task_code_type_product][:lost] = create_task_code( @origin_data[index_row][10][:id_task], @project[:task_code_type_product], @origin_data[index_row][2] )
		
			## Global task code Route 	
			@project[:task_code_type_route][:lost] = create_task_code( @origin_data[index_row][10][:id_task], @project[:task_code_type_route], ( ( route == nil ) ? @origin_data[index_row][4].to_s : route.to_s ) )

			## Global task code Step route 	
			@project[:task_code_type_step_route][:lost] = create_task_code( @origin_data[index_row][10][:id_task], @project[:task_code_type_step_route], step.to_s, false )
		
			## Global task code Route_full
			@project[:task_code_type_route_full][:lost] = create_task_code( @origin_data[index_row][10][:id_task], @project[:task_code_type_route_full], @origin_data[index_row][4] )
			
			## Global task code DO 
			@project[:task_code_type_do][:lost] = create_task_code( @origin_data[index_row][10][:id_task], @project[:task_code_type_do], ( @origin_data[index_row][5].empty? ? "none" : @origin_data[index_row][5] ) )
		
			## Global task code Material
			@project[:task_code_type_material][:lost] = create_task_code(@origin_data[index_row][10][:id_task], @project[:task_code_type_material], ( @origin_data[index_row][6].empty? ? "none" : @origin_data[index_row][6] ) )
		
		
			## Create user fields	
			## QTY ( ID=603 )
			@db_pmdb.exec( "INSERT INTO [dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_number])
VALUES (603, #{@origin_data[index_row][10][:id_task]}, #{@project[:id_project]}, #{@origin_data[index_row][7]})" )
		
			## Weight (ID=604)
			@db_pmdb.exec( "INSERT INTO [dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_text])
VALUES (604, #{@origin_data[index_row][10][:id_task]}, #{@project[:id_project]}, '#{@origin_data[index_row][8]}')" )
		
		
			## Create relationship
			## If not root level
			if id_parent != @project[:id_project_wbs]	
				@db_pmdb.exec( "DECLARE @id_relationship int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22)
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT
set @id_relationship = @pseq_num
INSERT INTO [tempPMDB].[dbo].[TASKPRED] ([task_pred_id], [task_id], [pred_task_id], [proj_id], [pred_proj_id], [pred_type] )
VALUES (@id_relationship, #{id_parent}, #{@origin_data[index_row][10][:id_task]}, #{@project[:id_project]}, #{@project[:id_project]}, 'PR_FS' )" )
			end	
		end
		
end

















