module Invoices
  class UndoPaidService
    def self.call(invoice:, undone_by:, explanation:)
      raise CanCan::AccessDenied, "Only landlord can undo payment" unless undone_by.landlord?
      raise ArgumentError, I18n.t("invoice.errors.explanation_required", default: "Vui lòng nhập lý do hủy xác nhận thanh toán.") if explanation.blank?

      ActiveRecord::Base.transaction do
        invoice.undo_paid!(by_user: undone_by, explanation: explanation)

        recipients = [ invoice.house.landlord.user, *invoice.target_users ].compact.uniq

        InvoiceUnpaidNotifier.with(
          invoice: invoice,
          invoice_id: invoice.id,
          house_id: invoice.house_id,
          code: invoice.code,
          room_name: invoice.room.title_name,
          actor_name: undone_by.fullname,
          explanation: explanation
        ).deliver_later(recipients) if recipients.any?

        invoice
      end
    end
  end
end
