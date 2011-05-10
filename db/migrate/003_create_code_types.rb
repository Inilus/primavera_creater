class CreateCodeTypes < ActiveRecord::Migration
  
  def self.up
    create_table :code_types do |table|
      table.column :type_id, :integer    
      table.column :name, :string
    end
  end
 
  def self.down
    drop_table :code_types
  end
  
end
