class AddDetailsToInvoicesAndInvoiceItems < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :start_date, :date
    add_column :invoices, :end_date, :date
    add_column :invoices, :title, :string, default: "Thu tiền hàng tháng"

    add_column :invoice_items, :start_date, :date
    add_column :invoice_items, :end_date, :date
    add_column :invoice_items, :prev_reading, :integer
    add_column :invoice_items, :latest_reading, :integer
    add_column :invoice_items, :note, :string
  end
end
