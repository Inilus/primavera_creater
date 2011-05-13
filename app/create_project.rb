# force_encoding: utf-8
#
# File: create_project.rb

require 'tiny_tds'  # https://github.com/rails-sqlserver/tiny_tds#readme

class CreateProject
  
  def initialize( config )
    @client = TinyTds::Client.new( :username => config[:db][:username], :password => config[:db][:password], :dataserver => config[:db][:dataserver], :database => config[:db][:database] )
        
	end
  
  def save_data( project )
    @project = project
    
		## ProgressBar
		pbar = ProgressBar.new( "Save in PMDB", @project.tasks.size )

			## Create Project
			create_project
	
			## Iterator to all rows. Load data to Primavera
			@project.tasks.each_with_index do |task, index| 
			  create_task( task )
			  
			  ## ProgressBar
				pbar.inc								
			end
		
		## ProgressBar
		pbar.finish
	end
		  
  
  private
  
		def create_project
			# Select last id project & id wbs
			@project.id_project_prim = @client.execute( createSqlQuery( :select_id_new_project ) ).each( :symbolize_keys => true )[0][:key_seq_num]
			@project.id_wbs_prim = @client.execute( createSqlQuery( :select_id_new_projwbs ) ).each( :symbolize_keys => true )[0][:key_seq_num]

###############################################################						
#			code_tmp = @client.execute( createSqlQuery( :select_id_and_short_name_actv_code, { :id_task_code_type => code_type.id_prim, :value => code.short_name } ) ).each( :symbolize_keys => true )[0]
#			## If code does't find, create code
#			unless code_tmp.nil?
#			  code.id_prim = code_tmp[:actv_code_id] 
#		  else
#		    ## Select id last task code
#				code.id_prim = @client.execute( createSqlQuery( :select_id_new_actv_code ) ).each( :symbolize_keys => true )[0][:key_seq_num]
#				code.short_name = "none" if ( code.short_name.nil? or code.short_name.empty? )
#        code.name = code.short_name if ( code.name.nil? or code.name.empty? )
#        code.save 

#				@client.execute( createSqlQuery( :insert_new_actv_code, { :code_type_id => code_type.id_prim, :code => code } ) ).do

#			  
#			  @client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => task.id_prim, :id_code_type => code_type.id_prim, :code => code } ) ).do   
#		  end
#			@project.id_project_type_prim = code.id_prim
###############################################################			
			
			@project.save

			@client.execute( createSqlQuery( :insert_new_project_and_projwbs ) )

		  ## Global task code
		  code_types = CodeType.all
		  code_types.each do |code_type|
		    find_or_create_by_code_name( code_type )
		  end		  
		end
		
		def find_or_create_by_code_name( code_type, type="AS_Global" )
			data = @client.execute( createSqlQuery( :select_id_and_name_actv_type_code, { :name => code_type.name, :type => type } ) ).each( :as => :array )[0]
			if data == nil
				data = @client.execute( createSqlQuery( :select_id_new_actv_type_code ) ).each( :as => :array )[0]
				@client.execute(createSqlQuery( :insert_new_actv_type_code, { :name => code_type.name, :type => type } ) ).do
			end
			code_type.id_prim = data[0]
			code_type.save
		end
		
    def create_task( task )
    
			## Select last id task
			task.id_prim = @client.execute( createSqlQuery( :select_id_new_task ) ).each( :symbolize_keys => true )[0][:key_seq_num]
			task.duration         = 24 if ( ( task.duration.nil? ) or ( task.duration == 0 ) ) 
		  task.material_qty     = 0  if ( task.material_qty.nil? )
			task.material_weight  = 0  if ( task.material_weight.nil? ) 
			task.labor_units      = 0  if ( task.labor_units.nil? ) 
			task.save

			@client.execute( createSqlQuery( :insert_new_task, { :task => task } ) ).do
 
			## Create global task code 
		  CodeType.all.each do |code_type|
		    find_or_create_task_code( task, code_type )
		  end	
		  	  

			## Create user fields		
			## QTY ( ID=603 )
			@client.execute( createSqlQuery( :insert_new_udf_text, { :udf_id => 603, :task_id => task.id_prim, :value => task.material_qty } ) ).do
			## Weight (ID=604)
			@client.execute( createSqlQuery( :insert_new_udf_number, { :udf_id => 604, :task_id => task.id_prim, :value => task.material_weight } ) ).do		
					
			## Labor unit (ID=706)
			@client.execute( createSqlQuery( :insert_new_udf_number, { :udf_id => 706, :task_id => task.id_prim, :value => task.labor_units } ) ).do
################################# 			
			## Num operations (ID=708)
			@client.execute( createSqlQuery( :insert_new_udf_text, { :udf_id => 708, :task_id => task.id_prim, :value => task.num_operations } ) ).do
################################# 

			## Create relationship
			## If not root level
			unless task.parent.nil?
				@client.execute( createSqlQuery( :insert_relationship, { :task => task } ) ).do
			end
		end
		
# TODO: Add caching task code.
		def find_or_create_task_code( task, code_type )
      ## Find in cache
#		  ( id_task, task_code_type, value, long_value="", cached=true )
#			if cached and ( task_code_type.include?( :lost ) and task_code_type[:lost].include?(:value) and	task_code_type[:lost][:value] == value )
#				lost = task_code_type[:lost]
#			else
#			  lost = Hash.new
#				lost[:value] = value
#				if task_code_type.include?( :num_lost )
#					lost[:num_lost] += 1
#				else
#					lost[:num_lost] = 0
#				end
   
      code = task.codes.find_by_code_type_id( code_type.id )
      unless code.nil?
				code_tmp = @client.execute( createSqlQuery( :select_id_and_short_name_actv_code, { :id_task_code_type => code_type.id_prim, :value => code.short_name } ) ).each( :symbolize_keys => true )[0]
				## If code does't find, create code
				unless code_tmp.nil?
				  code.id_prim = code_tmp[:actv_code_id] 
			  else
			    ## Select id last task code
					code.id_prim = @client.execute( createSqlQuery( :select_id_new_actv_code ) ).each( :symbolize_keys => true )[0][:key_seq_num]
					code.short_name = "none" if ( code.short_name.nil? or code.short_name.empty? )
          code.name = code.short_name if ( code.name.nil? or code.name.empty? )
          code.save 

					@client.execute( createSqlQuery( :insert_new_actv_code, { :code_type_id => code_type.id_prim, :code => code } ) ).do
			  end
			  
			  @client.execute( createSqlQuery( :insert_new_relationship_actv_code_with_task, { :id_task => task.id_prim, :id_code_type => code_type.id_prim, :code => code } ) ).do   
		  end 
		end
		
  
    def createSqlQuery( name_query, params={} )
		  case name_query
		    
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
INSERT INTO [dbo].[PROJECT] ([proj_id], [fy_start_month_num], [allow_complete_flag], [project_flag], [name_sep_char], [proj_short_name], [clndr_id], [plan_start_date], [guid]) VALUES ( @id_project, 1, 'Y', 'Y', '.', '#{ @project.short_name }', 1408, 0, @GUID_project );
INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [ev_compute_type], [ev_etc_compute_type], [guid]) VALUES (@id_projwbs, @id_project, 565, 100, 1.00, 'Y', 'WS_Open', '#{ @project.short_name }', '#{ @project.name }', 6366, 6, 0.88, 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs); "

		    ## def create_task
		    when :select_id_new_task
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='task_task_id';"
		    when :insert_new_task
		    	## Required: params{ :task }
		    	return "DECLARE @id_task int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22);
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'task_task_id', @pseq_num = @pseq_num OUTPUT;
set @id_task = @pseq_num;
EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
set @GUID_task = @EncGUID;
INSERT INTO [dbo].[TASK]
( [task_id], [proj_id], [wbs_id], [clndr_id], [est_wt], [complete_pct_type], [task_type], [duration_type], [review_type], [status_code], [task_code], [task_name], [remain_drtn_hr_cnt], [target_drtn_hr_cnt], [late_start_date], [late_end_date], [cstr_type], [guid])
VALUES (@id_task, #{ @project.id_project_prim }, #{ @project.id_wbs_prim }, 1408, 1.0, 'CP_Drtn', 'TT_Task', 'DT_FixedRate', 'RV_OK', 'TK_NotStart', '#{ params[:task].short_name }', '#{ params[:task].name.slice( 0, 300 ) }', #{ params[:task].duration }, #{ params[:task].duration }, null, null, 'CS_ALAP', @GUID_task)"
		    when :insert_new_udf_text
		    	## Required: params{ :udf_id, :task_id, :value }
		    	return "INSERT INTO [dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_number])
VALUES ( #{ params[:udf_id] }, #{ params[:task_id] }, #{ @project.id_project_prim }, #{ params[:value] } ); "
		    when :insert_new_udf_number
		    	## Required: params{ :udf_id, :task_id, :value }
		    	return "INSERT INTO [dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_text])
VALUES ( #{ params[:udf_id] }, #{ params[:task_id] }, #{ @project.id_project_prim }, '#{ params[:value] }'); "
		    when :insert_relationship
		    	## Required: params{ :task }
          return "DECLARE @id_relationship int, @pseq_num int;
EXEC	[dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT;
set @id_relationship = @pseq_num;
INSERT INTO [dbo].[TASKPRED] ( [task_pred_id], [task_id], [pred_task_id], [proj_id], [pred_proj_id], [pred_type] )
VALUES ( @id_relationship, #{ params[:task].parent.id_prim }, #{ params[:task].id_prim }, #{ @project.id_project_prim }, #{ @project.id_project_prim }, 'PR_FS' ); "

		    ## def create_task_code
		    when :select_id_and_short_name_actv_code
		    	## Required: params{ :id_task_code_type, :value }
# TODO Add autodetect id parent code		    	
		    	return "SELECT TOP 1 actv_code_id, short_name, actv_code_name FROM [dbo].[ACTVCODE] WHERE [actv_code_type_id]=#{ params[:id_task_code_type] } AND [short_name]='#{ params[:value] }' AND [parent_actv_code_id]=4776 ; "
		    when :select_id_new_actv_code
		    	## Required: params{ }
		    	return "SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='actvcode_actv_code_id'; "
		    when :insert_new_actv_code
		    	## Required: params{ :code_type_id, :code }
		    	return "DECLARE @id_code int, @pseq_num int;
EXEC [dbo].[pc_get_next_key] @pkey_name = 'actvcode_actv_code_id', @pseq_num = @pseq_num OUTPUT;
set @id_code = @pseq_num;
INSERT INTO [dbo].[ACTVCODE] ( [actv_code_id], [actv_code_type_id], [seq_num], [short_name], [actv_code_name] )
VALUES ( @id_code, #{ params[:code_type_id] }, 100, '#{ params[:code].short_name.slice( 0, 60 ) }', '#{ params[:code].name }' ); "
		    when :insert_new_relationship_actv_code_with_task
		    	## Required: params{ :id_task, id_code_type, :code }
		    	return  "INSERT INTO [dbo].[TASKACTV]
([task_id], [actv_code_type_id], [actv_code_id], [proj_id])
VALUES (#{ params[:id_task] }, #{ params[:id_code_type] }, #{ params[:code].id_prim }, #{ @project.id_project_prim })"          
		    else
		    	return nil
		  end
	  end
end
