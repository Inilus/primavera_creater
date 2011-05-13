

class TaskCode < ActiveRecord::Base
    belongs_to :task
    belongs_to :code
end
