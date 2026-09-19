class AddIndexesToContractsAndInvoices < ActiveRecord::Migration[8.1]
  def change
    add_index :contracts, [ :end_date, :due_date ]
    add_index :invoices, [ :status, :due_date ]
  end
end
