class AddPaymentTrackingToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :paid_by_id, :bigint
    add_column :invoices, :paid_by_role, :string
    add_column :invoices, :undo_reason, :text
    add_column :invoices, :undone_at, :datetime
    add_column :invoices, :undone_by_id, :bigint

    add_index :invoices, :paid_by_id
    add_index :invoices, :undone_by_id

    reversible do |dir|
      dir.up do
        execute "UPDATE invoices SET payment_method = 'transfer' WHERE payment_method = 'bank_transfer'"
        execute "UPDATE invoices SET payment_method = NULL WHERE status != 'paid'"
      end
    end
  end
end
