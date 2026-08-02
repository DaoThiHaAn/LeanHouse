class CreateTenantStays < ActiveRecord::Migration[8.0]
 def change
    create_table :tenant_stays do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :rental_unit, null: false, foreign_key: true

      t.datetime :check_in, null: false
      t.datetime :check_out
      t.boolean :has_contract, null: false, default: false

      t.timestamps
    end

    add_check_constraint :tenant_stays,
                         "check_out IS NULL OR check_out >= check_in",
                         name: "tenant_stays_valid_dates"

    add_index :tenant_stays,
              :tenant_id,
              unique: true,
              where: "check_out IS NULL",
              name: "index_tenant_stays_on_active_tenant"

    add_index :tenant_stays,
              :rental_unit_id,
              unique: true,
              where: "check_out IS NULL",
              name: "index_tenant_stays_on_active_rental_unit"

    add_index :tenant_stays, [ :tenant_id, :check_in ]
    add_index :tenant_stays, [ :rental_unit_id, :check_in ]
  end
end
