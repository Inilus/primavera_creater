

class Task < ActiveRecord::Base
    belongs_to :project
    has_many :codes, :through => :task_codes
end
