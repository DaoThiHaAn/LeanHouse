class CreateRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :rooms do |t|
      t.references :floor, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :tenants_count, default: 0
      t.integer :max_slots, default: 1
      t.float :area, null: false

      t.timestamps
    end

    add_index :rooms, [:floor_id, :name], unique: true
  end
end
