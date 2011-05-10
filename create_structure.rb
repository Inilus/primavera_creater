require 'win32ole'
require 'progressbar'

class SqlServer
    # This class manages database connection and queries
    attr_accessor :connection, :data, :fields

    def initialize(conn_string)
        @connection = nil
        @data = nil
		@conn_string = conn_string
    end

    def open
        # Open ADO connection to the SQL Server database        
        @connection = WIN32OLE.new('ADODB.Connection')
        @connection.ConnectionString = @conn_string
		@connection.Open
    end
	# connection_string = "Provider=SQLOLEDB.1;Persist Security Info=False;User ID=sa;password=primavera978;Initial Catalog=Temp;Data Source=primavera;Network Library=dbmssocn"

    def query(sql)
		open
		
		# Create an instance of an ADO Recordset
        recordset = WIN32OLE.new('ADODB.Recordset')
        # Open the recordset, using an SQL statement and the
        # existing ADO connection
        recordset.Open(sql, @connection)
        # Create and populate an array of field names
        @fields = []
        recordset.Fields.each do |field|
            @fields << field.Name
        end
        begin
            # Move to the first record/row, if any exist
            recordset.MoveFirst
            # Grab all records
            @data = recordset.GetRows
        rescue
            @data = []
        end
        recordset.Close
        # An ADO Recordset's GetRows method returns an array 
        # of columns, so we'll use the transpose method to 
        # convert it to an array of rows
        @data = @data.transpose
		
		close
    end
	
	def exec(sql)
		open
		
		@connection.Execute(sql)
		# recordset = @connection.Execute(sql)
		
		close
	end

    def close
        @connection.Close
    end
end

conn_string_to_db_structure =  "Provider=SQLOLEDB.1;"
conn_string_to_db_structure << "Persist Security Info=False;"
conn_string_to_db_structure << "User ID=privuser;"
conn_string_to_db_structure << "password=privuser;"
conn_string_to_db_structure << "Initial Catalog=Temp;"
conn_string_to_db_structure << "Data Source=primavera;"
conn_string_to_db_structure << "Network Library=dbmssocn"
@db_structure = SqlServer.new(conn_string_to_db_structure)
# @db_structure.open
# @db_structure.query("SELECT TOP 20 * FROM tbl_Structure;")
@db_structure.query("SELECT * FROM tbl_Structure;")
# @db_structure.close

#field_names = @db_structure.fields
@project = Hash::new

# Iterator to all rows with field "position" [3]. Prepared data for loaad to Primavera
pbar = ProgressBar.new("Prepare data", @db_structure.data.size)
@db_structure.data.each_index do |index_row|	
	str = @db_structure.data[index_row][3]
	# if position empty then it's root element
	unless str.empty?		
		# In circle search parent element by path
		for index_parent_row in 0..@db_structure.data.size-1 
			if @db_structure.data[index_parent_row][3] == str.slice(0, (str.rindex('/') == nil ? 0 : str.rindex('/')))
				rindex_flash = (str.rindex('/') == nil ? 0 : str.rindex('/'))
				@db_structure.data[index_row][10] = Hash[ "id_parent" => @db_structure.data[index_parent_row][0], "num" => str.slice( (rindex_flash == 0 ? 0 : (rindex_flash + 1) ), (str.size - rindex_flash ) ), "level" => str.split('/').size, "size_route" => @db_structure.data[index_row][7].split('-').size ] 
				break
			end
		end			
	else 
		if @project.empty?
			@project["name"] = @db_structure.data[index_row][5].slice(0, 200)
			@project["short_name"] = @project["name"].slice(0, 40)
			@project["id"] = @db_structure.data[index_row][0]
		end
	end
	
	# Print data
	# puts "id=" + @db_structure.data[index_row][0].to_s.ljust(3) + 
		# # str.ljust(10) +
		# (@db_structure.data[index_row][10] != nil ? " parent_id=" + @db_structure.data[index_row][10]["id_parent"].to_s + 
			# " num=" + @db_structure.data[index_row][10]["num"].to_s +
			# " level=" + @db_structure.data[index_row][10]["level"].to_s : "") +
		# " name=" + @db_structure.data[index_row][5]
	
	pbar.inc
end
pbar.finish

conn_string_to_db_pmdb =  "Provider=SQLOLEDB.1;"
conn_string_to_db_pmdb << "Persist Security Info=False;"
conn_string_to_db_pmdb << "User ID=privuser;"
conn_string_to_db_pmdb << "password=privuser;"
conn_string_to_db_pmdb << "Initial Catalog=tempPMDB;"
conn_string_to_db_pmdb << "Data Source=primavera;"
conn_string_to_db_pmdb << "Network Library=dbmssocn"
@db_pmdb = SqlServer.new(conn_string_to_db_pmdb)

@id_last_wbs = Array.new

def search_wbs_up_level(level)
	# Search id uplevel wbs
	while @id_last_wbs[level] == nil
		level -= 1
	end
	return level
end

def create_project
	# Select last id project & id wbs
	@db_pmdb.query("SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='project_proj_id';")
	@project["id_project"] = @db_pmdb.data[0][0]		
	@db_pmdb.query("SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='projwbs_wbs_id';")
	@project["id_project_wbs"] = @id_last_wbs[0] = @db_pmdb.data[0][0]	
		
	str_query = "DECLARE @id_project int, @id_projwbs int, @pseq_num int, @GUID_project varchar(22), @GUID_projwbs varchar(22), @EncGUID varchar(22)
	EXEC	[dbo].[pc_get_next_key] @pkey_name = 'project_proj_id', @pseq_num = @pseq_num OUTPUT
	set @id_project = @pseq_num
	EXEC	[dbo].[pc_get_next_key] @pkey_name = 'projwbs_wbs_id', @pseq_num = @pseq_num OUTPUT
	set @id_projwbs = @pseq_num
	EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
	set @GUID_project = @EncGUID
	EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
	set @GUID_projwbs = @EncGUID
	INSERT INTO [dbo].[PROJECT] ([proj_id], [fy_start_month_num], [allow_complete_flag], [project_flag], [name_sep_char], [proj_short_name], [clndr_id], [plan_start_date], [guid]) 
	VALUES (@id_project, 1, 'Y', 'Y', '.', '" + @project["short_name"] + "', 1408, 0, @GUID_project)
	INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [ev_compute_type], [ev_etc_compute_type], [guid]) 
	VALUES (@id_projwbs, @id_project, 565, 100, 1.00, 'Y', 'WS_Open', '" + @project["short_name"] + "', '" + @project["name"] + "', 6366, 6, 0.88, 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs)"
	@db_pmdb.exec(str_query)
end

def create_wbs(index_row)
	# Select last id wbs	
	@db_pmdb.query("SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='projwbs_wbs_id';")
	level = @db_structure.data[index_row][10]["level"]	
	@id_last_wbs[level] = @db_pmdb.data[0][0]	
		
	# Clear id_last_wbs for down levels
	if @id_last_wbs.size > (level + 1)		
		@id_last_wbs = @id_last_wbs.values_at(0..level)	
	end
	
	# Search id uplevel wbs
	level = search_wbs_up_level(level - 1)	
	
	str_query = "DECLARE @id_projwbs int, @pseq_num int, @GUID_projwbs varchar(22), @EncGUID varchar(22)			
	EXEC	[dbo].[pc_get_next_key] @pkey_name = 'projwbs_wbs_id', @pseq_num = @pseq_num OUTPUT
	set @id_projwbs = @pseq_num
	EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
	set @GUID_projwbs = @EncGUID			
	INSERT INTO [dbo].[PROJWBS] ([wbs_id], [proj_id], [obs_id], [seq_num], [est_wt], [proj_node_flag], [status_code], [wbs_short_name], [wbs_name], [parent_wbs_id], [ev_user_pct], [ev_etc_user_value], [dscnt_period_type], [ev_compute_type], [ev_etc_compute_type], [guid]) 
	VALUES (@id_projwbs, " + @project["id_project"].to_s + ", 565, 10, 1.00, 'N', 'WS_Open', '" + @db_structure.data[index_row][5].slice(0, 40) + "', '" + @db_structure.data[index_row][5].slice(0, 300) + "', " + @id_last_wbs[level].to_s + ", 6, 0.88, 'Month', 'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs)"
	@db_pmdb.exec(str_query)	
end

def create_task(index_row, route=nil, relationship_self=false)
	id_parent = @db_structure.data.select { |row| row[0] == @db_structure.data[index_row][10]["id_parent"] }
	id_parent = ( ( not id_parent.empty? and id_parent[0][10] != nil and id_parent[0][10].include?("id_task") ) ? id_parent[0][10]["id_task"].to_s : @project["id_project_wbs"] )
	# If not root level, search id parent task
	if ( @db_structure.data[index_row][10]["id_parent"] != @project["id"] or relationship_self ) and @db_structure.data[index_row][10].include?("id_task")
			id_parent = @db_structure.data[index_row][10]["id_task"].to_s		
	end
	
	# Select last id task
	@db_pmdb.query("SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='task_task_id';")	
	@db_structure.data[index_row][10]["id_task"] = @db_pmdb.data[0][0]
	
	str_query = "DECLARE @id_task int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22)
	EXEC	[dbo].[pc_get_next_key] @pkey_name = 'task_task_id', @pseq_num = @pseq_num OUTPUT
	set @id_task = @pseq_num
	EXEC	[dbo].[get_guid] @EncGUID = @EncGUID OUTPUT
	set @GUID_task = @EncGUID
	INSERT INTO [dbo].[TASK] ( [task_id], [proj_id], [wbs_id], [clndr_id], [est_wt], [complete_pct_type], [task_type], [duration_type], [review_type], [status_code], [task_code], [task_name], [remain_drtn_hr_cnt], [target_drtn_hr_cnt], [late_start_date], [late_end_date], [cstr_type], [guid])
	VALUES 
	(@id_task, " + @project["id_project"].to_s + ", " + @id_last_wbs[@db_structure.data[index_row][10]["level"]].to_s + ", 1408, 1.0, 'CP_Drtn', 'TT_Task', 'DT_FixedRate', 'RV_OK', 'TK_NotStart', '" + @task_code.next! + "', '" + @db_structure.data[index_row][5].slice(0, 300) + "', 168, 168, null, null, 'CS_ALAP', @GUID_task)"			
	@db_pmdb.exec(str_query)
	
	# Create user fields
	# Routes (ID=598)
	str_query = "INSERT INTO [dbo].[UDFVALUE] 
	([udf_type_id], [fk_id], [proj_id], [udf_text])
	VALUES 
	(598, " + @db_structure.data[index_row][10]["id_task"].to_s + ", " + @project["id_project"].to_s + ", '" + (route == nil ? @db_structure.data[index_row][7].to_s : route.to_s) + "')"
	@db_pmdb.exec(str_query)	
	# Plots (ID=599)
	str_query = "INSERT INTO [tempPMDB].[dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_text])
	VALUES (599, " + @db_structure.data[index_row][10]["id_task"].to_s + ", " + @project["id_project"].to_s + ", '" + @db_structure.data[index_row][4] + "')"
	@db_pmdb.exec(str_query)	
	# Materials (ID=600)
	str_query = "INSERT INTO [tempPMDB].[dbo].[UDFVALUE] ([udf_type_id], [fk_id], [proj_id], [udf_text])
	VALUES (600, " + @db_structure.data[index_row][10]["id_task"].to_s + ", " + @project["id_project"].to_s + ", '" + @db_structure.data[index_row][6] + "')"
	@db_pmdb.exec(str_query)	
	
	
	# Create relationship
	# If not root level
	if id_parent != @project["id_project_wbs"]
		# Select id last id relationship
		# @db_pmdb.query("SELECT TOP 1 key_seq_num FROM [dbo].[NEXTKEY] WHERE key_name='taskpred_task_pred_id';")
		
		str_query = "DECLARE @id_relationship int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22)
		EXEC	[dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT
		set @id_relationship = @pseq_num
		INSERT INTO [tempPMDB].[dbo].[TASKPRED] ([task_pred_id], [task_id], [pred_task_id], [proj_id], [pred_proj_id], [pred_type] )
		VALUES (@id_relationship, " + id_parent.to_s + ", " + @db_structure.data[index_row][10]["id_task"].to_s + ", " + @project["id_project"].to_s + ", " + @project["id_project"].to_s + ", 'PR_FS' )"
		@db_pmdb.exec(str_query)
	# else 
		# if index_row_1st_levels != nil					
			# str_query = "DECLARE @id_relationship int, @pseq_num int, @GUID_task	varchar(22), @EncGUID varchar(22)
			# EXEC	[dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT
			# set @id_relationship = @pseq_num
			# INSERT INTO [tempPMDB].[dbo].[TASKPRED] ([task_pred_id], [task_id], [pred_task_id], [proj_id], [pred_proj_id], [pred_type] )
			# VALUES (@id_relationship, " + @db_structure.data[index_row][10]["id_task"].to_s + ", " + @db_structure.data[index_row_1st_levels][10]["id_task"].to_s + ", " + @project["id_project"].to_s + ", " + @project["id_project"].to_s + ", 'PR_FS' )"
			# @db_pmdb.exec(str_query)
		# end
		# index_row_1st_levels = index_row
	end	
end

unless @project.empty?
	pbar = ProgressBar.new("Save in PMDB", @db_structure.data.size)
	# @db_pmdb.open
	
	# Create Project
	create_project		
	
	# Iterator to all rows. Load data to Primavera
	# index_row_1st_levels = nil
	@task_code = "A00000"
	@db_structure.data.each_index do |index_row|
		# If row with description task, not project
		if @db_structure.data[index_row][10] != nil
			# Create WBS
			# If root level, then create WBS
			if @db_structure.data[index_row][10]["id_parent"] == @project["id"]				
				create_wbs(index_row)
			end
						
			# Create Task									
			# Search id uplevel wbs
			level = @db_structure.data[index_row][10]["level"] = search_wbs_up_level(@db_structure.data[index_row][10]["level"])
			if @db_structure.data[index_row][10]["size_route"] > 1
				# # Create WBS
				# level = @db_structure.data[index_row][10]["level"] += 1				
				# create_wbs(index_row)
				
				# Split route and create tasks
				@db_structure.data[index_row][7].reverse.split('-').each do |route|				
					create_task(index_row, route.reverse, true)
				end
				
				# @id_last_wbs[level] = nil
			else					
				create_task(index_row)
			end
		end
		pbar.inc
	end
		
	# @db_pmdb.close
	
	pbar.finish
	puts "Finish: Ok!"
end


















