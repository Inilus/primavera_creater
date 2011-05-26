# force_encoding: utf-8
#
# File: create_project.rb

require 'tiny_tds'  # https://github.com/rails-sqlserver/tiny_tds#readme

class CreateProject

  def initialize( config )
    @client = TinyTds::Client.new(
        :username => config[:db][:username],
        :password => config[:db][:password],
        :dataserver => config[:db][:dataserver],
        :database => config[:db][:database] )

    @name_code_structure = "Structure"
  end

  def save_data( project )
    @project = project

    ## ProgressBar
    pbar = ProgressBar.new( "Save in PMDB", @project.tasks.size )

      ## Create Project
      create_project

      ## Iterator to all rows. Load data to Primavera
      @project.tasks.each do |task|
        create_task( task )

        ## ProgressBar
        pbar.inc
      end

    ## ProgressBar
    pbar.finish
  end


  private

    def create_project
      ## Select last id project & id wbs
      @project.id_project_prim = @client.
          execute( createSqlQuery( :select_id_new_project ) ).
          each( :symbolize_keys => true )[0][:key_seq_num]
      @project.id_wbs_prim = @client.
          execute( createSqlQuery( :select_id_new_projwbs ) ).
          each( :symbolize_keys => true )[0][:key_seq_num]
      @project.save

      @client.execute( createSqlQuery( :insert_new_project_and_projwbs ) )

      ## Global task code
      code_types = CodeType.all
      code_types.each do |code_type|
        find_or_create_by_code_name( code_type )
      end

      @project.id_project_type_prim = @client.
          execute( createSqlQuery( :select_id_and_short_name_actv_code,
            { :id_prim_task_code_type => CodeType.find_by_name( @name_code_structure ).id_prim,
              :value => @project.project_type } ) ).
          each( :symbolize_keys => true )[0][:actv_code_id]
      @project.save
    end

    def find_or_create_by_code_name( code_type, type="AS_Global" )
      data = @client.
          execute( createSqlQuery( :select_id_and_name_actv_type_code,
            { :name => code_type.name, :type => type } ) ).
          each( :as => :array )[0]

      if data == nil
        data = @client.
            execute( createSqlQuery( :select_id_new_actv_type_code ) ).
            each( :as => :array )[0]
        @client.
            execute( createSqlQuery( :insert_new_actv_type_code,
              { :name => code_type.name, :type => type } ) ).do
      end

      code_type.id_prim = data[0]
      code_type.save
    end

    def create_task( task )

      ## Select id_prim for task
      task.id_prim = @client.
          execute( createSqlQuery( :select_id_new_task ) ).
          each( :symbolize_keys => true )[0][:key_seq_num]

#      # Default duration = 24h
#      task.duration         = 24 if task.duration == 0
      task.material_weight  = 0  if ( task.material_weight.nil? )
      task.save

      @client.execute( createSqlQuery( :insert_new_task, { :task => task } ) ).do

      ## Create global task code
      CodeType.all.each do |code_type|
        find_or_create_task_code( task, code_type )
      end

      ## Create user fields
      ## QTY
      @client.execute( createSqlQuery(
            :insert_new_udf_text,
            { :udf_id => find_udf_by_type_label( "Количество" ),
              :task_id => task.id_prim,
              :value => task.qty } ) ).do
      ## Weight
      @client.execute( createSqlQuery(
            :insert_new_udf_number,
            { :udf_id => find_udf_by_type_label( "Масса" ),
              :task_id => task.id_prim,
              :value => task.material_weight } ) ).do

      ## Labor unit
      @client.execute( createSqlQuery(
            :insert_new_udf_number,
            { :udf_id => find_udf_by_type_label( "Трудоёмкость по ТП" ),
              :task_id => task.id_prim,
              :value => task.labor_units } ) ).do

      ## Num operations
      @client.execute( createSqlQuery(
            :insert_new_udf_text,
            { :udf_id => find_udf_by_type_label( "Номера операций" ),
              :task_id => task.id_prim,
              :value => task.num_operations } ) ).do

      ## Labor units for num operations
#      @client.execute( createSqlQuery(
#            :insert_new_udf_text,
#            { :udf_id => find_udf_by_type_label( "Трудоёмкость по номерам операций" ),
#              :task_id => task.id_prim,
#              :value => task.labor_units_nums } ) ).do

      ## Labor units for all operations
#      sum = 0
#      task.labor_units_nums.gsub( ",", "." ).each_line( '-' ) { |s| sum += s.sub( "-", "" ).to_i } if task.labor_units_nums != "none"
#      @client.execute( createSqlQuery(
#            :insert_new_udf_number,
#            { :udf_id => find_udf_by_type_label( "Трудоёмкость всех операций" ),
#              :task_id => task.id_prim,
#              :value => sum } ) ).do

      ## Create relationship
      ## If no-root level
      unless task.parent.nil?
        @client.execute( createSqlQuery(
              :insert_relationship,
              { :task => task } ) ).do
      end
    end

    def find_udf_by_type_label( type_label, table_name="TASK" )
      udf_type = @client.
          execute( createSqlQuery(
            :select_id_udf_type,
            { :table_name => table_name,
              :type_label => type_label } ) ).
          each( :symbolize_keys => true )[0]

      if udf_type.nil?
        puts "Don't find UDF TYPE with label: #{ type_label }!"
        exit( 1 )
      end

      return udf_type[:udf_type_id]
    end

    def find_or_create_task_code( task, code_type )
      # Select code for current code_type
      code = task.codes.find_by_code_type_id( code_type.id )
      unless code.nil?
        ## Cached code#id_prim
        if code.id_prim.nil?
          if code_type.name == @name_code_structure
            parent_code_id = @project.id_project_type_prim
            code_tmp = nil
            # Partition by "."
            code.short_name.each_line( "." ) do |str|
              # Remove "."
              str = str.sub( ".", "" )
              code_tmp = @client.
                  execute( createSqlQuery( :select_id_and_short_name_actv_code,
                    { :id_prim_task_code_type => code_type.id_prim,
                      :value => str,
                      :id_prim_parent_task_code => parent_code_id } ) ).
                  each( :symbolize_keys => true )[0]
              parent_code_id = code_tmp[:actv_code_id]
            end

            unless code_tmp.nil?
              code.id_prim    = code_tmp[:actv_code_id]
              code.short_name = code_tmp[:short_name]
              code.save
            end

          else
            code_tmp = @client.
                execute( createSqlQuery( :select_id_and_short_name_actv_code,
                  { :id_prim_task_code_type => code_type.id_prim,
                    :value => code.short_name } ) ).
                each( :symbolize_keys => true )[0]

            # If code not exist - create new code
            unless code_tmp.nil?
              code.id_prim = code_tmp[:actv_code_id]
              code.save
            else
              # Select id last task code
              code.id_prim = @client.
                  execute( createSqlQuery( :select_id_new_actv_code ) ).
                  each( :symbolize_keys => true )[0][:key_seq_num]
              code.short_name = "none" if ( code.short_name.nil? or code.short_name.empty? )
              code.name = code.short_name if ( code.name.nil? or code.name.empty? )
              code.save

              @client.execute( createSqlQuery( :insert_new_actv_code,
                  { :code_type_id => code_type.id_prim, :code => code } ) ).do
            end

          end
        end

        @client.
          execute( createSqlQuery( :insert_new_relationship_actv_code_with_task,
            { :id_task => task.id_prim,
              :id_code_type => code_type.id_prim,
              :code => code } ) ).do unless code_type.id_prim.nil?
      end
    end

    def createSqlQuery( name_query, params={} )
      case name_query

        ## def create_type_task_code
        when :select_id_and_name_actv_type_code
          ## Required: params{ :name, :type }
          return %(
            SELECT TOP 1 actv_code_type_id, actv_code_type
            FROM [dbo].[ACTVTYPE]
            WHERE [actv_code_type]='#{ params[:name] }'
              AND [actv_code_type_scope]='#{ params[:type] }'; )
        when :select_id_new_actv_type_code
          ## Required: params{ }
          return %(
            SELECT TOP 1 key_seq_num
            FROM [dbo].[NEXTKEY]
            WHERE key_name='actvtype_actv_code_type_id'; )
        when :insert_new_actv_type_code
          ## Required: params{ :name, :type }
          return %(
            DECLARE @id_type_code int, @pseq_num int;
            EXEC  [dbo].[pc_get_next_key] @pkey_name = 'actvtype_actv_code_type_id', @pseq_num = @pseq_num OUTPUT;
            set @id_type_code = @pseq_num;
            INSERT INTO [dbo].[ACTVTYPE]
              ( [actv_code_type_id], [actv_short_len], [seq_num],
                [actv_code_type], [actv_code_type_scope], [super_flag] )
            VALUES ( @id_type_code, 60, 0, '#{ params[:name] }', '#{ params[:type] }', 'N' ); )

        ## def create_project
        when :select_id_new_project
          ## Required: params{ }
          return %(
            SELECT TOP 1 key_seq_num
            FROM NEXTKEY
            WHERE key_name='project_proj_id'; )
        when :select_id_new_projwbs
          ## Required: params{ }
          return %(
            SELECT TOP 1 key_seq_num
            FROM [dbo].[NEXTKEY]
            WHERE key_name='projwbs_wbs_id'; )
        when :insert_new_project_and_projwbs
          ## Required: params{ }
          return %(
            DECLARE @id_project int, @id_projwbs int, @pseq_num int,
              @GUID_project varchar(22), @GUID_projwbs varchar(22),
              @EncGUID varchar(22);
            EXEC  [dbo].[pc_get_next_key] @pkey_name = 'project_proj_id', @pseq_num = @pseq_num OUTPUT;
            set @id_project = @pseq_num;
            EXEC  [dbo].[pc_get_next_key] @pkey_name = 'projwbs_wbs_id', @pseq_num = @pseq_num OUTPUT;
            set @id_projwbs = @pseq_num;
            EXEC  [dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
            set @GUID_project = @EncGUID;
            EXEC  [dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
            set @GUID_projwbs = @EncGUID;
            INSERT INTO [dbo].[PROJECT]
              ( [proj_id], [fy_start_month_num], [allow_complete_flag],
                [project_flag], [name_sep_char], [proj_short_name], [clndr_id],
                [plan_start_date], [guid] )
              VALUES ( @id_project, 1, 'Y', 'Y', '.', '#{ @project.short_name }',
                1408, 0, @GUID_project );
            INSERT INTO [dbo].[PROJWBS]
              ( [wbs_id], [proj_id], [obs_id], [seq_num], [est_wt],
                [proj_node_flag], [status_code], [wbs_short_name], [wbs_name],
                [parent_wbs_id], [ev_user_pct], [ev_etc_user_value],
                [ev_compute_type], [ev_etc_compute_type], [guid] )
              VALUES ( @id_projwbs, @id_project, 565, 100, 1.00, 'Y', 'WS_Open',
                '#{ @project.short_name }', '#{ @project.name }', 3667, 6, 0.88,
                'EV_Cmp_pct', 'EE_Rem_hr', @GUID_projwbs ); )

        ## def create_task
        when :select_id_new_task
          ## Required: params{ }
          return %(
            SELECT TOP 1 key_seq_num
            FROM [dbo].[NEXTKEY]
            WHERE key_name='task_task_id'; )
        when :insert_new_task
          ## Required: params{ :task }
          return %(
            DECLARE @id_task int, @pseq_num int, @GUID_task varchar(22), @EncGUID varchar(22);
            EXEC [dbo].[pc_get_next_key] @pkey_name = 'task_task_id', @pseq_num = @pseq_num OUTPUT;
            set @id_task = @pseq_num;
            EXEC [dbo].[get_guid] @EncGUID = @EncGUID OUTPUT;
            set @GUID_task = @EncGUID;
            INSERT INTO [dbo].[TASK]
              ( [task_id], [proj_id], [wbs_id], [clndr_id], [est_wt],
                [complete_pct_type], [task_type], [duration_type], [review_type],
                [status_code], [task_code], [task_name], [remain_drtn_hr_cnt],
                [target_drtn_hr_cnt], [late_start_date], [late_end_date],
                [cstr_type], [guid] )
              VALUES ( @id_task, #{ @project.id_project_prim },
                #{ @project.id_wbs_prim }, 639, 1.0, 'CP_Drtn', 'TT_Task',
                'DT_FixedRate', 'RV_OK', 'TK_NotStart',
                '#{ params[:task].short_name }',
                '#{ params[:task].name.slice( 0, 300 ) }',
                #{ params[:task].duration.ceil },
                #{ params[:task].duration.ceil }, null, null, 'CS_ALAP',
                @GUID_task ); )
        when :insert_new_udf_number
          ## Required: params{ :udf_id, :task_id, :value }
          return %(
            INSERT INTO [dbo].[UDFVALUE]
              ( [udf_type_id], [fk_id], [proj_id], [udf_number] )
              VALUES ( #{ params[:udf_id] }, #{ params[:task_id] },
                #{ @project.id_project_prim }, #{ params[:value] } ); )
        when :insert_new_udf_text
          ## Required: params{ :udf_id, :task_id, :value }
          return %(
            INSERT INTO [dbo].[UDFVALUE]
              ( [udf_type_id], [fk_id], [proj_id], [udf_text] )
              VALUES ( #{ params[:udf_id] }, #{ params[:task_id] },
                #{ @project.id_project_prim }, '#{ params[:value] }' ); )
        when :insert_relationship
          ## Required: params{ :task }
          return %(
            DECLARE @id_relationship int, @pseq_num int;
            EXEC [dbo].[pc_get_next_key] @pkey_name = 'taskpred_task_pred_id', @pseq_num = @pseq_num OUTPUT;
            set @id_relationship = @pseq_num;
            INSERT INTO [dbo].[TASKPRED]
              ( [task_pred_id], [task_id], [pred_task_id], [proj_id],
                [pred_proj_id], [pred_type] )
              VALUES ( @id_relationship, #{ params[:task].parent.id_prim },
                #{ params[:task].id_prim }, #{ @project.id_project_prim },
                #{ @project.id_project_prim }, 'PR_FS' ); )

        ## def create_task_code
        when :select_id_and_short_name_actv_code
          ## Required: params{ :id_prim_task_code_type, :value, [ :id_prim_parent_task_code ] }
          return %(
            SELECT TOP 1 actv_code_id, short_name, actv_code_name
            FROM [dbo].[ACTVCODE]
            WHERE [actv_code_type_id]=#{ params[:id_prim_task_code_type] }
              AND [short_name]='#{ params[:value] }'
              #{ "AND [parent_actv_code_id]=#{ params[:id_prim_parent_task_code] }" if params.include?( :id_prim_parent_task_code ) }; )
        when :select_id_new_actv_code
          ## Required: params{ }
          return %(
            SELECT TOP 1 key_seq_num
            FROM [dbo].[NEXTKEY]
            WHERE key_name='actvcode_actv_code_id'; )
        when :insert_new_actv_code
          ## Required: params{ :code_type_id, :code }
          return %(
            DECLARE @id_code int, @pseq_num int;
            EXEC [dbo].[pc_get_next_key] @pkey_name = 'actvcode_actv_code_id', @pseq_num = @pseq_num OUTPUT;
            set @id_code = @pseq_num;
            INSERT INTO [dbo].[ACTVCODE]
              ( [actv_code_id], [actv_code_type_id], [seq_num], [short_name],
                [actv_code_name] )
              VALUES ( @id_code, #{ params[:code_type_id] }, 100,
                '#{ params[:code].short_name.slice( 0, 60 ) }',
                '#{ params[:code].name }' ); )
        when :insert_new_relationship_actv_code_with_task
          ## Required: params{ :id_task, id_code_type, :code }
          return %(
            INSERT INTO [dbo].[TASKACTV]
              ( [task_id], [actv_code_type_id], [actv_code_id], [proj_id] )
              VALUES ( #{ params[:id_task] }, #{ params[:id_code_type] },
                #{ params[:code].id_prim }, #{ @project.id_project_prim } ); )

        ## def find_or_create_udf_by_type_label
        when :select_id_udf_type
          ## Required: params{ :table_name, :type_label }
          return %(
            SELECT TOP 1 [udf_type_id]
            FROM [dbo].[UDFTYPE]
            WHERE [table_name]='#{ params[:table_name] }'
              AND [udf_type_label]='#{ params[:type_label] }'
              AND [delete_date] IS NULL; )

        else
          return nil
      end
    end
end

