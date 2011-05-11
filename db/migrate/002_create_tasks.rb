class CreateTasks < ActiveRecord::Migration
  
  def self.up
    create_table :tasks do |t|
      t.integer    :parent_id
      t.integer    :id_1c
      t.integer    :parent_id_1c
      t.integer    :id_prim
      t.string     :short_name
      t.string     :name
      t.float      :duration      
      t.float      :labor_units 
      t.integer    :material_qty
      t.float      :material_weight            
      t.timestamps
    end
  end
 
  def self.down
    drop_table :tasks
  end
  
end
