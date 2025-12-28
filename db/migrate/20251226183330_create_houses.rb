class CreateHouses < ActiveRecord::Migration[8.0]
  def change
    create_table :houses do |t|
      t.string :name, null: false
      t.string :address_l1, null: false
      t.string :address_l2, null: false
      t.string :address_l3, null: false

      t.integer :floors_count, null: false, default: 1
      t.integer :rooms_count, null: false, default: 1
      t.integer :inv_creation_date, null: false, default: 1

      t.timestamps
      t.datetime :deleted_at

      t.references :landlord, null: false, foreign_key: true
    end
  end
end
