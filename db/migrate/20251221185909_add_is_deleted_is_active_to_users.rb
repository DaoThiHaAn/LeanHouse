class AddIsDeletedIsActiveToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_deleted, :boolean, null: false, default: false
    add_column :users, :is_active, :boolean, null: false, default: true
  end
end
