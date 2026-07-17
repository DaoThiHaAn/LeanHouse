class RemoveRentFromRooms < ActiveRecord::Migration[8.0]
  def change
    remove_column :rooms, :rent, :integer
  end
end
