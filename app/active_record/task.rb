

class Task < ActiveRecord::Base
    belongs_to :project
    
    has_many :tasks, :class_name => "Task", :foreign_key => "parent_id"
    belongs_to :parent, :class_name => "Task"
    
    has_many :task_codes
    has_many :codes, :through => :task_codes
  
end
