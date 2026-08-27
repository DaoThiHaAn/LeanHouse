class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.references :tenant, null: false, foreign_key: { on_delete: :cascade }
      t.references :house, null: false, foreign_key:  { on_delete: :cascade }

      t.string :license_plate, null: false
      t.string :vehicle_type, null: false, default: "motorbike"
      t.string :brand
      t.string :model

      t.timestamps
    end

    add_index :vehicles, [ :license_plate, :house_id ], unique: true
  end
end
