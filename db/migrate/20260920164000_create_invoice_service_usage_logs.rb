# frozen_string_literal: true

class CreateInvoiceServiceUsageLogs < ActiveRecord::Migration[7.2]
  def up
    create_table :invoice_service_usage_logs do |t|
      t.references :invoice, null: false, foreign_key: { on_delete: :cascade }
      t.references :service_usage_log, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :invoice_service_usage_logs,
              [ :invoice_id, :service_usage_log_id ],
              unique: true,
              name: "idx_inv_usage_logs_unique"

    # Migrate existing relationships
    execute <<-SQL.squish
      INSERT INTO invoice_service_usage_logs (invoice_id, service_usage_log_id, created_at, updated_at)
      SELECT invoice_id, id, NOW(), NOW()
      FROM service_usage_logs
      WHERE invoice_id IS NOT NULL
      ON CONFLICT DO NOTHING
    SQL

    remove_reference :service_usage_logs, :invoice, foreign_key: true, index: true
  end

  def down
    add_reference :service_usage_logs, :invoice, foreign_key: { on_delete: :nullify }, index: true

    execute <<-SQL.squish
      UPDATE service_usage_logs
      SET invoice_id = sub.invoice_id
      FROM (
        SELECT DISTINCT ON (service_usage_log_id) service_usage_log_id, invoice_id
        FROM invoice_service_usage_logs
        ORDER BY service_usage_log_id, created_at ASC
      ) sub
      WHERE service_usage_logs.id = sub.service_usage_log_id
    SQL

    drop_table :invoice_service_usage_logs
  end
end
