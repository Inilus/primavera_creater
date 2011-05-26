class CreateCodes < ActiveRecord::Migration

  def self.up
    create_table :codes do |t|
      t.references :code_type
      t.integer    :id_prim
      t.string     :short_name
      t.string     :name
      t.timestamps
    end

#    add index      :short_name, :name
  end

  def self.down
    drop_table :codes
  end

end

