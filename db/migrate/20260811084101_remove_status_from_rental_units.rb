class RemoveStatusFromRentalUnits < ActiveRecord::Migration[8.0]
  def change
    remove_column :rental_units, :status, :string
  end
end
