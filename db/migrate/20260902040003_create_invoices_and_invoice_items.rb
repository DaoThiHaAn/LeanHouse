class CreateInvoicesAndInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.string     :code, null: false
      t.references :house, null: false, foreign_key: { on_delete: :cascade }
      t.references :room, null: false, foreign_key: { on_delete: :cascade }
      t.references :tenant, null: true, foreign_key: { on_delete: :nullify }
      t.references :bank_account, null: true, foreign_key: { on_delete: :nullify }
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string     :invoice_type, null: false, default: "room"
      t.date       :billing_month, null: false
      t.date       :due_date, null: false

      t.bigint     :subtotal, null: false, default: 0
      t.bigint     :total_discount, null: false, default: 0
      t.bigint     :total_addition, null: false, default: 0
      t.bigint     :total_amount, null: false, default: 0

      t.string     :status, null: false, default: "pending"
      t.datetime   :paid_at
      t.string     :payment_method
      t.string     :transfer_note
      t.text       :note

      t.datetime   :discarded_at
      t.timestamps
    end

    add_index :invoices, :code, unique: true
    add_index :invoices, [ :room_id, :billing_month, :invoice_type ], name: "idx_invoices_room_month_type"
    add_index :invoices, [ :house_id, :billing_month ]
    add_index :invoices, :status

    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }
      t.references :service_variant, null: true, foreign_key: { on_delete: :nullify }

      t.string     :item_type, null: false
      t.string     :name, null: false
      t.string     :unit
      t.bigint     :unit_price, default: 0, null: false
      t.decimal    :quantity, precision: 10, scale: 2, default: 1.0, null: false
      t.bigint     :amount, null: false

      t.timestamps
    end

    add_foreign_key :service_usage_logs, :invoices, column: :invoice_id, on_delete: :nullify
  end
end
