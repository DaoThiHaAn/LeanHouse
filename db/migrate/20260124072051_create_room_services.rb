class CreateRoomServices < ActiveRecord::Migration[8.0]
  def change
    create_table :room_services, primary_key: [ :service_id, :room_id ] do |t|
      t.integer :fee, null: false
      t.boolean :is_real_time, null: false, default: false
      t.string :unit, null: false

      t.references :service, null: false, foreign_key: { on_delete: :cascade }
      t.references :room, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
  end
end
