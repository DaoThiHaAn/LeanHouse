# frozen_string_literal: true

class InvoiceServiceUsageLog < ApplicationRecord
  belongs_to :invoice
  belongs_to :service_usage_log

  validates :invoice_id, uniqueness: { scope: :service_usage_log_id }
end
