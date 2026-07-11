class CreateRentalUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :rental_units do |t|
      # Rails auto generates rentable_type and rentable_id columns for polymorphic association
      t.references :rentable, polymorphic: true, null: false

      t.integer :rent, null: false
      t.integer :deposit, null: false
      t.boolean :is_deposited, null: false, default: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end
  end
end
