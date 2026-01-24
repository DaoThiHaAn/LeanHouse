class CreateRoomServices < ActiveRecord::Migration[8.0]
  def change
    create_table :room_services, id: false do |t|
      t.integer :fee, null: false
      t.boolean :is_real_time, null: false, default: false

      t.references :service, null: false, foreign_key: { on_delete: :cascade }
      t.references :room, null: false, foreign_key: { on_delete: :cascade }
      t.references :service_unit, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    # Composite primary key
    execute <<~SQL
      ALTER TABLE room_services
      ADD PRIMARY KEY (service_id, room_id);
    SQL
  end
end
