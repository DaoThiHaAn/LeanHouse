module Invoices
  class CancelService
    def self.call(invoice:, cancelled_by:)
      ActiveRecord::Base.transaction do
        invoice.update!(
          status: :cancelled,
          discarded_at: Time.current,
          note: [ invoice.note, "[Hủy bởi #{cancelled_by.fullname} lúc #{Time.current.strftime('%H:%M %d/%m/%Y')}]" ].compact_blank.join("\n")
        )

        # Unlink any associated service usage logs
        ServiceUsageLog.where(invoice_id: invoice.id).update_all(invoice_id: nil)

        invoice
      end
    end
  end
end
