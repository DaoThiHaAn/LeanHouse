class AddPayosFieldsToBankAccountsAndInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :bank_accounts, :payos_client_id, :string
    add_column :bank_accounts, :payos_api_key, :string
    add_column :bank_accounts, :payos_checksum_key, :string
    add_column :bank_accounts, :payos_enabled, :boolean, default: false, null: false

    add_column :invoices, :payos_order_code, :bigint
    add_column :invoices, :payos_payment_link_id, :string
    add_column :invoices, :payos_checkout_url, :string
    add_column :invoices, :payos_qr_code, :text
    add_column :invoices, :payos_status, :string

    add_index :invoices, :payos_order_code, unique: true
  end
end
