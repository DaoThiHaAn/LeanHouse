class AddDepositPaidToContracts < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :deposit_paid, :boolean, default: false, null: false
  end
end
