class CreateFloors < ActiveRecord::Migration[8.0]
  def change
    create_table :floors do |t|
      t.references :house, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :rooms_count, default: 0
      t.timestamps
    end

    add_index :floors, [ :house_id, :name ], unique: true
  end
end
