# force_encoding: utf-8
#
# File: ts_createStructure.rb

require 'test/unit'
require 'mocha'
require_relative 'createrStructure'

class TestCreateStructure < Test::Unit::TestCase

	def setup
		@creater = CreaterStructure.new
	end
	
	def test_load_data
		size = 100
		@creater.load_data( size )
		assert( @creater.origin_data.size <= size, "Lenght result array is big" )		
		if @creater.origin_data.size > 0
			assert_equal( @creater.origin_data[0].size, 9, "Not correct input data (count row in table, max = 10)" )
		end
	end

	def test_prepare_data
		# Prepare
		output_array = [
			[1,	-1,	"Name1",	"",					"",							"",					"",	1,	nil],
			[2,	1,	"Name2",	"P0898787", "4-7-2-4-6-1",	"91.11101",	"", 1,	nil]
		]		
		@creater.expects( :load_data ).returns( output_array )

		# Doing
		@creater.origin_data = @creater.load_data
		@creater.prepare_data

		# Check
		assert( ( @creater.get_project != nil ), "Don't have information about Project" )
		assert_equal( @creater.get_project[:name], output_array[0][2].slice( 0, 200 ), "Don't correct name Project" )
		assert_equal( @creater.get_project[:short_name], output_array[0][2].slice( 0, 40 ), "Don't correct short name Project" )
		assert_equal( @creater.get_project[:id], output_array[0][0], "Don't correct id Project" )

		assert_equal( @creater.origin_data[1], output_array[1], "Don't correct first element in origin_data[1]")
	end

	def test_fail_prepare_data
		# Prepare
		output_array = [
			[1,	1,	"Name1",	"",					"",							"",					"",	1,	nil],
			[2,	1,	"Name2",	"P0898787", "4-7-2-4-6-1",	"91.11101",	"", 1,	nil]
		]		
		@creater.expects( :load_data ).returns( output_array )

		# Doing
		@creater.origin_data = @creater.load_data
		@creater.prepare_data

		# Check
		assert( ( @creater.get_project == nil ) , "Don't have information about Project'" )
	end
	
end
