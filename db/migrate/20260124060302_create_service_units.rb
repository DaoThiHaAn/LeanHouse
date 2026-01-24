class CreateServiceUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :service_units do |t|
      t.string :code, null: false
    end

    create_table :service_unit_translations do |t|
      t.references :service_unit, null: false, foreign_key: { on_delete: :cascade }
      t.string :locale, null: false
      t.string :name, null: false
    end

    add_index :service_units, :code, unique: true
    add_index :service_unit_translations,
              [ :service_unit_id, :locale ],
              unique: true
  end
end
