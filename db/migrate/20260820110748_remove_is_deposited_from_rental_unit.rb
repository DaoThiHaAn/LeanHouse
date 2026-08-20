class RemoveIsDepositedFromRentalUnit < ActiveRecord::Migration[8.0]
  def change
    remove_column :rental_units, :is_deposited, :boolean
  end
end
