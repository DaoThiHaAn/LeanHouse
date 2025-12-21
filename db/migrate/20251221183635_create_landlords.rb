class CreateLandlords < ActiveRecord::Migration[8.0]
  def change
    create_table :landlords, id: false do |t|
      # use id as both primary key and foreign key
      t.bigint :id, null: false, primary_key: true
      t.integer :posts_count, null: false, default: 0
      t.integer :houses_count, null: false, default: 0

      t.timestamps
    end

    # add foreign key constraint to users.id
    add_foreign_key :landlords, :users, column: :id
  end
end
