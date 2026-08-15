class CreateContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :contracts do |t|
      t.references :tenant, null: false, foreign_key: { on_delete: :cascade }
      t.references :landlord, null: false, foreign_key: { on_delete: :cascade }
      t.references :house, null: false, foreign_key: { on_delete: :cascade }

      t.string :citizen_id, null: false
      t.boolean :temp_resid_registered, default: false
      t.date :temp_resid_due_date
      t.date :start_date, null: false
      t.date :due_date, null: false
      t.timestamps
    end

    add_check_constraint :contracts,
      "due_date > start_date",
      name: "contracts_due_date_after_start_date"
  end
end
