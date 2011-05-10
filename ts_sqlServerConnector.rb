# force_encoding: utf-8
#
# File: ts_sqlServerConnector.rb

require 'test/unit'
require 'mocha'
require_relative 'sqlServerConnector'

class TestSqlServer < Test::Unit::TestCase
	
	def setup
#		puts "Start setup"
		conn_string_to_db =  "Provider=SQLOLEDB.1;"
		conn_string_to_db << "Persist Security Info=False;"
		conn_string_to_db << "User ID=privuser;"
		conn_string_to_db << "password=privuser;"
		conn_string_to_db << "Initial Catalog=Temp;"
		conn_string_to_db << "Data Source=primavera;"
		conn_string_to_db << "Network Library=dbmssocn"
		
		@db = SqlServerConnector.new(conn_string_to_db)
	end
	
	def test_notnull
		assert_not_nil( @db, "Connection string is not correct" )		
	end
	
	def test_methods
#		assert_respond_to( @db, :open, "Don't work method Open" )
#		assert_respond_to( @db, :close, "Don't work method Close" )
	end

	def test_method_query
		size = 3
		assert_equal( size, @db.query("SELECT TOP #{size} * FROM tbl_Structure3;").size, "Don't working query to DB'")
	end

	def test_fail_method_query
		assert_not_equal( 3, @db.query("SELECT TOP 2 * FROM tbl_Structure3;").size, "Don't working query to DB'")
	end
	
	def test_mock_method_query			
		data_res = [ [ 2, 1, "Podogrevatel", "P00969312", "4-7T-4-7T-4-3-4C", "91.2710SB", "", 1, nil ], [ 3, 2, "Puchok", "P00969312\P00865690", "4C", "91.1085.01-01SB", "", 1, nil ] ]				
		@db.expects(:query).returns(data_res)
		
		assert_equal( data_res, @db.query( "SELECT TOP 3 * FROM tbl_Structure3;" ) )
	end
end
