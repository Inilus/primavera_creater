# force_encoding: utf-8
#
# File: runner.rb

require_relative  'creater'

class Runner
	def initialize
		if ARGV.empty? or ARGV[0].nil?
			puts "Incorrect parameter! For example: \"ruby runner.rb '91.2446'\""
  		exit( 1 )
		end
		
    @count = ( ARGV[1] != nil ) ? ARGV[0].to_i : -1
		
		@creater = Creater.new( ARGV[0].to_s )			
		
	end
	
	def run
		@creater.load_data( @count )
		@creater.save_data
		
	end
	
end

Runner.new.run
