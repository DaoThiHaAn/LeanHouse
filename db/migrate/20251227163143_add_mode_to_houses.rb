class AddModeToHouses < ActiveRecord::Migration[8.0]
  def change
    add_column :houses, :mode, :string
  end
end
