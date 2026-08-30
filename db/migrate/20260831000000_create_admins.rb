class CreateAdmins < ActiveRecord::Migration[8.0]
  def change
    create_table :admins do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :fullname, null: false
      t.string :role, default: "super_admin", null: false
      t.boolean :is_active, default: true, null: false
      t.datetime :last_login_at

      t.timestamps
    end

    add_index :admins, :email, unique: true
  end
end
