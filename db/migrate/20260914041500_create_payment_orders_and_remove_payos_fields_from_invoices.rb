# frozen_string_literal: true

class CreatePaymentOrdersAndRemovePayosFieldsFromInvoices < ActiveRecord::Migration[8.0]
  def up
    create_table :payment_orders do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }, index: true
      t.string :provider, null: false, default: "payos"
      t.bigint :order_code, null: false
      t.string :payment_link_id
      t.string :checkout_url
      t.text :qr_code
      t.string :status, default: "PENDING"
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :payment_orders, :order_code, unique: true
    add_index :payment_orders, [ :invoice_id, :provider ]

    execute <<-SQL
      INSERT INTO payment_orders (invoice_id, provider, order_code, payment_link_id, checkout_url, qr_code, status, created_at, updated_at)
      SELECT id, 'payos', payos_order_code, payos_payment_link_id, payos_checkout_url, payos_qr_code, COALESCE(payos_status, 'PENDING'), NOW(), NOW()
      FROM invoices
      WHERE payos_order_code IS NOT NULL;
    SQL

    remove_index :invoices, name: "index_invoices_on_payos_order_code" if index_exists?(:invoices, :payos_order_code, name: "index_invoices_on_payos_order_code")
    remove_column :invoices, :payos_order_code, :bigint
    remove_column :invoices, :payos_payment_link_id, :string
    remove_column :invoices, :payos_checkout_url, :string
    remove_column :invoices, :payos_qr_code, :text
    remove_column :invoices, :payos_status, :string
  end

  def down
    add_column :invoices, :payos_order_code, :bigint
    add_column :invoices, :payos_payment_link_id, :string
    add_column :invoices, :payos_checkout_url, :string
    add_column :invoices, :payos_qr_code, :text
    add_column :invoices, :payos_status, :string
    add_index :invoices, :payos_order_code, unique: true

    execute <<-SQL
      UPDATE invoices
      SET payos_order_code = po.order_code,
          payos_payment_link_id = po.payment_link_id,
          payos_checkout_url = po.checkout_url,
          payos_qr_code = po.qr_code,
          payos_status = po.status
      FROM payment_orders po
      WHERE invoices.id = po.invoice_id AND po.provider = 'payos';
    SQL

    drop_table :payment_orders
  end
end
