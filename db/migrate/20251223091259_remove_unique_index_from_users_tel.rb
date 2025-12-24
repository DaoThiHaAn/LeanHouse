class RemoveUniqueIndexFromUsersTel < ActiveRecord::Migration[8.0]
  def change
    remove_index :users, :tel if index_exists?(:users, :tel)
  end
end
