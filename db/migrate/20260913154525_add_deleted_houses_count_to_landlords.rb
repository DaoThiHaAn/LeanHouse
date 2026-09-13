class AddDeletedHousesCountToLandlords < ActiveRecord::Migration[8.1]
  def up
    add_column :landlords, :deleted_houses_count, :integer, default: 0, null: false

    execute <<-SQL.squish
      UPDATE landlords
      SET deleted_houses_count = (
        SELECT COUNT(*)
        FROM houses
        WHERE houses.landlord_id = landlords.id
          AND houses.is_deleted = TRUE
      )
    SQL
  end

  def down
    remove_column :landlords, :deleted_houses_count
  end
end
