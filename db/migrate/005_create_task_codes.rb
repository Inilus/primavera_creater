class CreateTaskCodes < ActiveRecord::Migration
  
  def self.up
    create_table :task_codes do |t|
      t.references  :task
      t.references  :code
      t.timestamps
    end
  end
 
  def self.down
    drop_table :task_codes
  end
  
end
