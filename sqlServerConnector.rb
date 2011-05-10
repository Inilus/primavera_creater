# force_encoding: utf-8
#
# File: sqlServerConnector.rb

require 'win32ole'

## This class manages database connection and queries
class SqlServerConnector
		def initialize(conn_string)
		  @connection	 = nil		 
			@conn_string = conn_string
		end
		
		def query(sql, transpose = true)
			open_and_close do 
				## Create an instance of an ADO Recordset
				recordset = WIN32OLE.new('ADODB.Recordset')
				## Open the recordset, using an SQL statement and the existing ADO connection
				recordset.Open(sql, @connection)
#				## Create and populate an array of field names
#    		@fields = []
#    		recordset.Fields.each do |field|
#      		@fields << field.Name
#    		end
				data = nil
				begin
				  ## Move to the first record/row, if any exist
				  recordset.MoveFirst
				  data = recordset.GetRows
				rescue
			    data = []
				end
				recordset.Close
				if transpose 
					return data.transpose
				end
				return data
			end		
		end
	
		def exec(sql)
			open_and_close do		
				@connection.Execute(sql)
			end
		end	

	private
		def open_and_close 
			# Open ADO connection to the SQL Server database        
		  @connection = WIN32OLE.new('ADODB.Connection')
		  @connection.ConnectionString = @conn_string
			@connection.Open		
			yield 			
			@connection.Close
		end  

end
