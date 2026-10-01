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

        recipients = if paid_by&.landlord?
                       # Landlord marked paid: notify tenants only
                       invoice.target_users.compact.uniq
                     else
                       # Tenant paid or automated (payOS): notify landlord and tenants
                       [ invoice.house.landlord.user, *invoice.target_users ].compact.uniq
                     end

        method_label = if invoice.cash?
                         I18n.t("invoice.payment_methods.cash", default: "Tiền mặt")
        else
                         I18n.t("invoice.payment_methods.transfer", default: "Chuyển khoản")
        end

        paid_by_role = paid_by ? paid_by.role : "payos"

        InvoicePaidNotifier.with(
          invoice: invoice,
          invoice_id: invoice.id,
          house_id: invoice.house_id,
          code: invoice.code,
          room_name: invoice.room&.title_name || invoice.target_name,
          amount: ApplicationController.helpers.format_money(invoice.total_amount),
          paid_by_role: paid_by_role,
          paid_by_id: paid_by&.id,
          actor_name: paid_by&.fullname || "payOS",
          method_label: method_label
        ).deliver_later(recipients) if recipients.any?

        invoice
      end
    end
  end
end
