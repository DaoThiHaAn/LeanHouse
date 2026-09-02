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

        # Deliver notification to target tenants
        tenant_users = invoice.target_users
        if tenant_users.present? && tenant_users.any?
          InvoiceCancelledNotifier.with(
            invoice: invoice,
            code: invoice.code,
            room_name: invoice.room.title_name,
            month: invoice.billing_month.strftime("%m/%Y"),
            raw_month: invoice.billing_month.strftime("%Y-%m"),
            house_id: invoice.house_id
          ).deliver_later(tenant_users)
        end

        invoice
      end
    end
  end
end
