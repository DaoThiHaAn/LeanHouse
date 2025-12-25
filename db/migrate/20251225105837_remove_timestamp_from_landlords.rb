class RemoveTimestampFromLandlords < ActiveRecord::Migration[8.0]
  def change
    remove_column :landlords, :created_at
    remove_column :landlords, :updated_at
  end
end
