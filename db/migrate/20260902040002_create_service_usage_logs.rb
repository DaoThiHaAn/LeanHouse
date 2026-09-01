class CreateServiceUsageLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :service_usage_logs do |t|
      t.references :room, null: false, foreign_key: { on_delete: :cascade }
      t.references :service, null: true, foreign_key: { on_delete: :nullify }
      t.references :service_variant, null: true, foreign_key: { on_delete: :nullify }
      t.bigint     :invoice_id, null: true

      t.string     :service_name, null: false
      t.string     :unit, null: false
      t.integer    :unit_price, null: false, default: 0

      t.date       :billing_month, null: false
      t.date       :start_date, null: false
      t.date       :end_date, null: false

      t.integer    :prev_reading, null: false, default: 0
      t.integer    :latest_reading
      t.integer    :usage_quantity

      t.boolean    :is_confirmed, null: false, default: false
      t.datetime   :confirmed_at
      t.references :submitted_by, polymorphic: true
      t.references :confirmed_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :service_usage_logs, [ :room_id, :service_id, :billing_month ], unique: true, name: "idx_usage_logs_room_service_month"
    add_index :service_usage_logs, :invoice_id
  end
end
