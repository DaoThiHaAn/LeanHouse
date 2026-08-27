class CreateVehicleRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicle_requests do |t|
      t.string :license_plate, null: false
      t.string :vehicle_type, null: false, default: "motorbike"

      t.string :brand
      t.string :model

      t.datetime :consent_given_at, null: false
      t.datetime :documents_purged_at

      t.timestamps
    end

    add_index :vehicle_requests, :license_plate
  end
end
