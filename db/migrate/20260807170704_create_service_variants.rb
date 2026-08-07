class CreateServiceVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :service_variants do |t|
      t.integer :fee, null: false, default: 0
      t.string :unit, null: false
      t.boolean :is_real_time, null: false, default: false

      t.references :service, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
