class AddDeletedToBeds < ActiveRecord::Migration[8.0]
  def change
    add_column :beds, :deleted, :boolean, default: false, null: false
  end
end
