class CreateRoomServices < ActiveRecord::Migration[8.0]
  def change
    create_table :room_services do |t|
      t.references :room, null: false,
                           foreign_key: { on_delete: :cascade }

      t.references :service_variant,
                   null: false,
                   foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :room_services,
              [ :room_id, :service_variant_id ],
              unique: true,
              name: "idx_room_service_variant"
  end
end
