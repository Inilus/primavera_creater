class CreateTaskCodes < ActiveRecord::Migration
  
  def self.up
    create_table :task_codes do |table|
      table.column :task_id, :integer
      table.column :code_id, :integer    
    end
  end
 
  def self.down
    drop_table :task_codes
  end
  
end
