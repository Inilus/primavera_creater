# force_encoding: utf-8
#
# File: creater.rb

#require 'profile'
require_relative 'createrStructure'

count = -1
if ARGV[0] != nil
  count = ARGV[0].to_i
end

puts "Start..."

creater = CreaterStructure.new
creater.load_data( count )
creater.prepare_data
creater.save_data

puts "Finish: Ok!"
