class CreateTasks < ActiveRecord::Migration
  
  def self.up
    create_table :tasks do |t|
      t.references :project
      t.integer    :parent_id
      t.integer    :id_prim
      t.integer    :id_1c
      t.integer    :parent_id_1c
      t.string     :short_name
      t.string     :name
      t.float      :duration,         :default => 0  
      t.string     :num_operations,   :default => "none"
      t.string     :labor_units_nums, :default => "none"
      t.float      :labor_units,      :default => 0      
      t.float      :labor_units_shrm, :default => 0
      t.integer    :material_qty,     :default => 0
      t.float      :material_weight,  :default => 0
      t.timestamps
    end
  end
 
  def self.down
    drop_table :tasks
  end
  
end
