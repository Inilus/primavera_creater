class CreateTasks < ActiveRecord::Migration
  
  def self.up
    create_table :tasks do |table|
      table.column :task_id, :integer
      table.column :task_id_1c, :integer
      table.column :project_id, :integer
      table.column :short_name, :string
      table.column :name, :string
      table.column :duration, :integer        
    end
  end
 
  def self.down
    drop_table :tasks
  end
  
end
