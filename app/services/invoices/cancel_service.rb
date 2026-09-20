module Invoices
  class CancelService
    def self.call(invoice:, cancelled_by:)
      if invoice.paid?
        raise ArgumentError, I18n.t("invoice.errors.cannot_cancel_paid", default: "Không thể hủy hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước.")
      end

      ActiveRecord::Base.transaction do
        invoice.update!(
          status: :cancelled,
          discarded_at: Time.current,
          note: [ invoice.note, "[Hủy bởi #{cancelled_by.fullname} lúc #{Time.current.strftime('%H:%M %d/%m/%Y')}]" ].compact_blank.join("\n")
        )

        # Unlink any associated service usage logs
        invoice.invoice_service_usage_logs.destroy_all

        # Cancel payOS payment link if exists
        cancel_payos_payment_link(invoice, cancelled_by)

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

    def self.cancel_payos_payment_link(invoice, cancelled_by)
      return unless invoice.payos_configured?
      return unless invoice.payos_order.present?

      reason = "Hóa đơn #{invoice.code} đã bị hủy bởi #{cancelled_by.fullname}"
      PayosService.cancel_payment_link(invoice, reason: reason)
    rescue StandardError => e
      Rails.logger.error("[Invoices::CancelService] Error cancelling payOS link: #{e.message}")
    end
  end
end
