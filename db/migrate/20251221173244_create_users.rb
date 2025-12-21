class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :fullname, null: false
      t.string :tel, null: false
      t.string :password_digest, null: false
      t.string :sex, limit: 1, null: false
      t.date :bday, null: false
      t.string :address, null: false

      t.timestamps
    end

    add_index :users, :tel, unique: true
  end
end
