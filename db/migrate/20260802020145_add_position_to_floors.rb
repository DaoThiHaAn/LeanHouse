class AddPositionToFloors < ActiveRecord::Migration[8.0]
  def up
    add_column :floors, :position, :integer

    # Give each floor within a house a sequential position
    House.find_each do |house|
      house.floors.order(:id).each.with_index(1) do |floor, index|
        floor.update_columns(position: index)
      end
    end

    change_column_null :floors, :position, false

    add_index :floors, [ :house_id, :position ], unique: true
  end

  def down
    remove_index :floors, column: [ :house_id, :position ]
    remove_column :floors, :position
  end
end
