class CreateProjects < ActiveRecord::Migration

  def self.up
    create_table :projects do |table|
      table.column :project_id, :integer
      table.column :wbs_id, :integer
      table.column :short_name, :string
      table.column :name, :string
      table.column :start_date, :string
    end
  end
 
  def self.down
    drop_table :projects
  end
  
end

