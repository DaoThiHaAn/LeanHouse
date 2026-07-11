class CreateBeds < ActiveRecord::Migration[8.0]
  def change
    create_table :beds do |t|
      t.references :room, null: false, foreign_key: true

      t.string :name, null: false
      t.boolean :is_available, null: false, default: true
    end
  end
end
