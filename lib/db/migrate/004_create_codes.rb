class CreateCodes < ActiveRecord::Migration
  
  def self.up
    create_table :codes do |table|
      table.column :code_id, :integer
      table.column :code_type_id, :integer    
      table.column :short_name, :string
      table.column :name, :string
    end
  end
 
  def self.down
    drop_table :codes
  end
  
end
