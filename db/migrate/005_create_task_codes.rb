class CreateTaskCodes < ActiveRecord::Migration
  
  def self.up
    create_table :task_codes do |t|
      t.integer     :task_id
      t.integer     :code_id
      t.timestamps
    end
  end
 
  def self.down
    drop_table :task_codes
  end
  
end
