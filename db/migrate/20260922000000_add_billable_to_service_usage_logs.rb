# frozen_string_literal: true

class AddBillableToServiceUsageLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :service_usage_logs, :billable, :boolean, null: false, default: true
    add_index :service_usage_logs, :billable
  end
end
