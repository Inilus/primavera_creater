class CreateProjects < ActiveRecord::Migration

  def self.up
    create_table :projects do |t|
      t.integer    :id_project_prim
      t.integer    :id_wbs_prim
      t.string     :project_type
      t.integer    :id_project_type_prim
      t.string     :short_name
      t.string     :name
      t.string     :start_date
      t.timestamps
    end
  end
 
  def self.down
    drop_table :projects
  end
  
end

