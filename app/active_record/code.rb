

class Code < ActiveRecord::Base
    belongs_to :code_type
    has_many :tasks, :through => :task_codes
end
