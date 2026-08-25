class AddStatusToAssets < ActiveRecord::Migration[8.0]
  def change
    add_column :assets, :status, :string, default: "normal", null: false
  end
end
