

class Code < ActiveRecord::Base
    belongs_to :code_type
    has_many :tasks, :through => :task_codes
    
    def find_or_create_by_short_name( short_name, name=nil )
      code = Code.find_by_short_name( short_name ) 
      code = Code.create( :short_name => short_name, :name => name ) if code.nil? 
      return code
    end
end
