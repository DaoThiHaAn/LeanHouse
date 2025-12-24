class RemoveIsDeleletedFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :is_deleted
  end
end
