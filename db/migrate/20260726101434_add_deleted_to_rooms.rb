class AddDeletedToRooms < ActiveRecord::Migration[8.0]
  def change
    add_column :rooms, :deleted, :boolean, default: false, null: false
  end
end
