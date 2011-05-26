class CreateCodeTypes < ActiveRecord::Migration

  def self.up
    create_table :code_types do |t|
      t.integer     :id_prim
      t.string      :name
      t.timestamps
    end

#    add index       :name
  end

  def self.down
    drop_table :code_types
  end

end

