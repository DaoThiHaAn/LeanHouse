class CreateMaintenanceLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :maintenance_logs do |t|
      t.references :asset, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :cost, default: 0, null: false
      t.string :content, null: false
      t.date :performed_on, null: false

      t.timestamps
    end
  end
end
