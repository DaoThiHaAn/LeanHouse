class CreateServices < ActiveRecord::Migration[8.0]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :note
      t.references :house, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
