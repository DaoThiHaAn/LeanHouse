module Invoices
  class MarkPaidService
    def self.call(invoice:, paid_by:, params: {})
      method = params[:payment_method].presence || "transfer"
      method = "transfer" if method.to_s == "bank_transfer"
      proof = params[:payment_proof]
      payment_note = params[:note]

      ActiveRecord::Base.transaction do
        invoice.mark_as_paid!(
          by_user: paid_by,
          method: method,
          proof: proof,
          payment_note: payment_note
        )

        recipients = [ invoice.house.landlord.user, *invoice.target_users ].compact.uniq

        method_label = if invoice.cash?
                         I18n.t("invoice.payment_methods.cash", default: "Tiền mặt")
        else
                         I18n.t("invoice.payment_methods.transfer", default: "Chuyển khoản")
        end

        InvoicePaidNotifier.with(
          invoice: invoice,
          invoice_id: invoice.id,
          house_id: invoice.house_id,
          code: invoice.code,
          room_name: invoice.room.title_name,
          amount: invoice.formatted_total_amount,
          paid_by_role: paid_by.role,
          paid_by_id: paid_by.id,
          actor_name: paid_by.fullname,
          method_label: method_label
        ).deliver_later(recipients) if recipients.any?

        invoice
      end
    end
  end
end
