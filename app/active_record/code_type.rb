

class CodeType < ActiveRecord::Base
    has_many :codes   
    
    def find_or_create_by_name( value )
      code_type = CodeType.find_by_name( value ) 
      code_type = CodeType.create( :name => value ) if code_type.nil? 
      return code_type
    end
end
