class CreateAssets < ActiveRecord::Migration[8.0]
  def change
    create_table :assets do |t|
      t.references :room, null: false, foreign_key: { on_delete: :cascade }
      t.integer :price, null: false
      t.date :purchased_at
      t.string :brand
      t.string :model
      t.string :category, null: false
      t.string :note

      t.timestamps
    end
  end
end
