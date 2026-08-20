class AddEndDateToContracts < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :end_date, :date
  end
end
