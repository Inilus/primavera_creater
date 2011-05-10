# force_encoding: utf-8
#
# File: creater.rb
#
# Docs for Yaml: 				http://santoro.tk/mirror/ruby-core/classes/YAML.html
# Docs for ProgressBar: http://0xcc.net/ruby-progressbar/index.html.en
# Docs for TinyTds: 		https://github.com/rails-sqlserver/tiny_tds#readme

require 'yaml'
require 'progressbar'
require 'tiny_tds'

class Creater
	def initialize( name_project )
		config = YAML.load_file( "config.yml" )
		@client = TinyTds::Client.new( :username => config[:db][:username], :password => config[:db][:password], :dataserver => config[:db][:dataserver], :database => config[:db][:database] )
		
		@structures = YAML.load_file( "structures.yml" )
		
		@project 		 = {
										:name 			=> name_project.slice( 0, 200 ),
										:short_name => name_project.slice( 0, 40 )
									 }
		@origin_data = nil
		
		@code_wbs 	 = config[:code][:wbs]
		@code_task 	 = config[:code][:task]
		
	end
	
	def load_data( count=-1, from="tbl_Structure4" )
		@client.execute( createSqlQuery( :use_temp ) ).do
		@origin_data = @client.execute( createSqlQuery( :select_all_from_tmp_table, { :count => count, :from => from, :project_name => @project[:short_name] } ) ).each( :symbolize_keys => true )
		if @origin_data.empty?
			puts "Error! Don't find Project with name \"#{ project_name }\""
			exit( 1 )
		end		
		return @origin_data
	end
	
	def save_data
			## ProgressBar
			pbar = ProgressBar.new( "Save in PMDB", @origin_data.size )

			unless @project.nil?
				## Create Project
				create_project

				@project[:task_code_type][:product][:top_level] = Hash.new
				## Iterator to all rows. Load data to Primavera
				@origin_data.each_with_index do |row, index|
					if row[:top_level]
						## Create global task code
						## Global task code Product			
						@project[:task_code_type][:product][:top_level][ row[:do] ] = create_task_code( @project[:task_code_type][:product], row[:name], "", row[:id_code] )	
					else
						if not @project[:task_code_type][:product][:top_level][ row[:do] ].nil?
							row[:id_code] = @project[:task_code_type][:product][:top_level][ row[:do] ]
						end
						create_task( row )					
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
		

	
	private
		
		def create_project
			@client.execute( createSqlQuery( :use_tempPmdb ) ).do
			# Select last id project & id wbs
			@project[:id_project] = @client.execute( createSqlQuery( :select_id_new_project ) ).each( :symbolize_keys => true )[0][:key_seq_num]
			@project[:id_project_wbs] = @client.execute( createSqlQuery( :select_id_new_projwbs ) ).each( :symbolize_keys => true )[0][:key_seq_num]

			@client.execute( createSqlQuery( :insert_new_project_and_projwbs ) )

		  ## Global task code
		  @project[:task_code_type] = Hash.new
			## Global task code Product
			@project[:task_code_type][:product]     			= create_type_task_code( "Product" )
			## Global task code PPU
			@project[:task_code_type][:ppu]      					= create_type_task_code( "PPU" )
			## Global task code DO
			@project[:task_code_type][:do]          			= create_type_task_code( "DO" )
			## Global task code Sequence assembly
			@project[:task_code_type][:sequence_assembly] = create_type_task_code( "Sequence assembly" )
		end
		
		def create_type_task_code( name, type="AS_Global" )
			data = @client.execute( createSqlQuery( :select_id_and_name_actv_type_code, { :name => name, :type => type } ) ).each( :as => :array )[0]
			if data == nil
				data = @client.execute( createSqlQuery( :select_id_new_actv_type_code ) ).each( :as => :array )[0]
				data[1] = name

				@client.execute(createSqlQuery( :insert_new_actv_type_code, { :name => name, :type => type } ) ).do
			end
			return Hash[ :id => data[0], :name_type => data[1] ]
		end
		
		def create_task( row )
			## Create global task code
			## Global task code Product				
			@project[:task_code_type][:product][:lost] = create_task_code( @project[:task_code_type][:product], row[:name], "", row[:id_code] )
			# Global task code DO
			@project[:task_code_type][:do][:lost] = create_task_code( @project[:task_code_type][:do], ( row[:do].empty? ? "none" : row[:do] ) )
			## Global task code PPU
			@project[:task_code_type][:ppu][:lost] = create_task_code( @project[:task_code_type][:ppu], row[:ppu] )
			## Global task code Sequence assembly
			@project[:task_code_type][:sequence_assembly][:lost] = create_task_code( @project[:task_code_type][:sequence_assembly], ( row[:sa].to_s.empty? ? "none" : row[:sa].to_s ) )
			
			row[:id_tasks] = Array.new
			row[:relationships] = Array.new
			
			structure = @structures[( row[:type_product] - 1 )]
			structure[:branches].each do |branche|
				## Select last id task				
				id_task = row[:id_tasks][ branche[:id] ] = @client.execute( createSqlQuery( :select_id_new_task ) ).each( :symbolize_keys => true )[0][:key_seq_num]
				
				## Create task
				@client.execute( createSqlQuery( :insert_new_task, { :row => branche } ) ).do
			
				## Global task code Product
				@client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => id_task, :task_code => @project[:task_code_type][:product] } ) ).do			
				## Global task code DO
				@client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => id_task, :task_code => @project[:task_code_type][:do] } ) ).do	
				## Global task code PPU
				@client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => id_task, :task_code => @project[:task_code_type][:ppu] } ) ).do	
				## Global task code Sequence assembly
				@client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => id_task, :task_code => @project[:task_code_type][:sequence_assembly] } ) ).do	
						
				relationships = structure[:relationships].select { |rs| rs[:id_finish] == branche[:id] }								
				relationships.each do |relationship|	
					row[:relationships] << { 
																	:id_start => relationship[:id_start], 
																	:id_finish => branche[:id],
																	:type => relationship[:type], 
																	:delay => ( relationship[:delay].nil? ? 0 : relationship[:delay] )
																 }
				end				
			end
			
			row[:relationships].each do |relationship|
				@client.execute( createSqlQuery( :insert_relationship, { :id_parent => row[:id_tasks][ relationship[:id_finish] ], :id_task => row[:id_tasks][ relationship[:id_start] ], :type => relationship[:type], :delay => relationship[:delay] } ) ).do
			end
		end
		
		def create_task_code( task_code_type, value, long_value="", id_parent_task_code=nil )
		  lost = Hash.new
			lost[:value] = value
			if task_code_type.include?( :num_lost )
				lost[:num_lost] += 1
			else
				lost[:num_lost] = 0
			end
			id_parent_task_code = "null" if id_parent_task_code.nil?

			lost[:id] = @client.execute( createSqlQuery( :select_id_and_short_name_actv_code, { :id_task_code_type => task_code_type[:id], :value => value } ) ).each( :symbolize_keys => true )
			## If code does't exist, else create code
			if not lost[:id].empty?
        lost[:id] = lost[:id][0][:actv_code_id]
      else
				## Select id last task code
				lost[:id] = @client.execute( createSqlQuery( :select_id_new_actv_code ) ).each( :symbolize_keys => true )[0][:key_seq_num]
        long_value = value if long_value.empty?        
				@client.execute( createSqlQuery( :insert_new_actv_code, { :id_task_code_type => task_code_type[:id], :num_lost => lost[:num_lost], :value => value, :long_value => long_value, :id_parent_task_code => id_parent_task_code } ) ).do
			end
			
			return lost
		end
	
	
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
INSERT INTO [dbo].[PROJECT] ([proj_id], [fy_start_month_num], [allow_complete_flag], [project_flag], [name_sep_char], [proj_short_name], [clndr_id], [plan_start_date], [guid]) VALUES ( @id_project, 1, 'Y', 'Y', '.', '#{ @project[:short_name] }', 1408, 0, @GUID_project );
INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [ev_compute_type], [ev_etc_compute_type], [guid]) VALUES (@id_projwbs, @id_project, 565, 100, 1.00, 'Y', 'WS_Open', '#{ @project[:short_name] }', '#{ @project[:name] }', 6366, 6, 0.88, 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs); "

		    ## def create_task
		    when :select_id_new_task
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='task_task_id';"
		    when :insert_new_task
		    	## Required: params{ :row }
		    	case params[:row][:type]
		    		when :task 			
		    			type =  "TT_Task"
		    		when :milestone 
		    			type =  "TT_Mile"		    			
		    		else 						
		    			type =  "TT_Task"
		    	end
		    	params[:row][:duration] = 24 if params[:row][:duration].nil?
		    	return "DECLARE @id_task int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22);
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'task_task_id', @pseq_num = @pseq_num OUTPUT;
set @id_task = @pseq_num;
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
set @GUID_task = @EncGUID;
INSERT INTO [dbo].[TASK]
( [task_id], [proj_id], [wbs_id], [clndr_id], [est_wt], [complete_pct_type], [task_type], [duration_type], [review_type], [status_code], [task_code], [task_name], [remain_drtn_hr_cnt], [target_drtn_hr_cnt], [late_start_date], [late_end_date], [cstr_type], [guid])
VALUES (@id_task, #{ @project[:id_project] }, #{ @project[:id_project_wbs] }, 1408, 1.0, 'CP_Drtn', '#{ type }', 'DT_FixedRate', 'RV_OK', 'TK_NotStart', '#{ @code_task.next! }', '#{ params[:row][:name].slice( 0, 300 ) }', #{ params[:row][:duration] }, #{ params[:row][:duration] }, null, null, '', @GUID_task)"
		    when :insert_relationship
		    	## Required: params{ :id_parent, :id_task [, :type, :delay ] }
		    	params[:delay] = 0 if params[:delay].nil?
		    	case params[:type]
		    		when :FS 
		    			type = "PR_FS"
		    		when :SF 
		    			type = "PR_SF"
		    		when :SS 
		    			type = "PR_SS"
		    		when :FF 
		    			type = "PR_FF"
		    		else 
		    			type = "PR_FS"
		    	end
		    	sql = "DECLARE @id_relationship int, @pseq_num int;
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT;
set @id_relationship = @pseq_num;
INSERT INTO [dbo].[TASKPRED] ( [task_pred_id], [task_id], [pred_task_id], [proj_id], [pred_proj_id], [pred_type], [lag_hr_cnt] )
VALUES ( @id_relationship, #{ params[:id_parent] }, #{ params[:id_task] }, #{ @project[:id_project] }, #{ @project[:id_project] }, '#{ type }', #{ params[:delay] } ); "
		    	return  sql
				when :select_id_actvcode_type
					## Required: params{ :name_actvtype }
					return "SELECT TOP 1 ACTVTYPE.[actv_code_type_id] 
FROM [dbo].[ACTVTYPE] AS ACTVTYPE
WHERE ACTVTYPE.[actv_code_type] LIKE '#{ params[:name_actvtype] }'"


		    ## def create_task_code
		    when :select_id_and_short_name_actv_code
		    	## Required: params{ :id_task_code_type, :value }
		    	return "SELECT TOP 1 actv_code_id, short_name FROM [dbo].[ACTVCODE] WHERE [actv_code_type_id]=#{ params[:id_task_code_type] } AND [actv_code_name]='#{ params[:value] }'; "
		    when :select_id_new_actv_code
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='actvcode_actv_code_id'; "
		    when :insert_new_actv_code
		    	## Required: params{ :id_task_code_type, :num_lost, :long_value, :value, :id_parent_task_code }
		    	params[:id_parent_task_code] = "null" if params[:id_parent_task_code].nil?
		    	return "DECLARE @id_code int, @pseq_num int;
EXEC [dbo].[pc_get_next_key] @pkey_name = 'actvcode_actv_code_id', @pseq_num = @pseq_num OUTPUT;
set @id_code = @pseq_num;
INSERT INTO [dbo].[ACTVCODE] ( [actv_code_id], [actv_code_type_id], [seq_num], [short_name], [actv_code_name], [parent_actv_code_id] )
VALUES ( @id_code, #{ params[:id_task_code_type] }, #{ params[:num_lost] }, '#{ params[:value].to_s.slice(0,60) }', '#{ params[:long_value].to_s }', #{ params[:id_parent_task_code] } ); "
		    when :insert_new_relationship_actv_code_with_task
		    	## Required: params{ :id_task, :task_code }
		    	return "INSERT INTO [dbo].[TASKACTV]
([task_id], [actv_code_type_id], [actv_code_id], [proj_id])
VALUES (#{ params[:id_task] }, #{ params[:task_code][:id] }, #{ params[:task_code][:lost][:id] }, #{ @project[:id_project] })"

		    else
		    	return nil
		  end
		end
	
end
