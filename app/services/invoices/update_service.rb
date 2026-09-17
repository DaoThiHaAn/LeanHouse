# frozen_string_literal: true

module Invoices
  class UpdateService
    def self.call(...)
      new(...).call
    end

    def initialize(invoice:, house:, params:)
      @invoice = invoice
      @house = house
      @params = params
    end

    def call
      if invoice.paid?
        invoice.errors.add(:base, I18n.t("invoice.errors.cannot_update_paid", default: "Không thể chỉnh sửa hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước nếu cần thay đổi."))
        return false
      end

      return false unless invoice.update(params.except(:transfer_note_mode))

      sync_item_dates_if_needed
      sync_transfer_note
      sync_payos_payment_link_if_needed
      deliver_notifications

      true
    end

    private

    attr_reader :invoice, :house, :params

    def sync_payos_payment_link_if_needed
      return if invoice.paid? || invoice.cancelled?

      if invoice.saved_change_to_bank_account_id?
        invoice.payment_orders.where(provider: "payos").destroy_all
        invoice.ensure_payos_payment_link! if invoice.payos_configured?
      end
    end

    def sync_item_dates_if_needed
      if params[:start_date].present? || params[:end_date].present?
        invoice.invoice_items.update_all(
          start_date: invoice.start_date,
          end_date: invoice.end_date
        )
      end
    end

    def sync_transfer_note
      mode = params[:transfer_note_mode]
      return unless mode.present? || params.key?(:transfer_note)

      new_note = case mode
      when "none"
                   nil
      when "custom"
                   TransferNoteBuilder.sanitize(params[:transfer_note])
      when "system"
                   TransferNoteBuilder.build(house.transfer_note_template, invoice)
      else
                   params[:transfer_note].present? ? TransferNoteBuilder.sanitize(params[:transfer_note]) : nil
      end

      invoice.update_column(:transfer_note, new_note)
    end

    def deliver_notifications
      tenant_users = invoice.target_users
      return if tenant_users.blank?

      InvoiceUpdatedNotifier.with(
        invoice: invoice,
        code: invoice.code,
        room_name: invoice.room.title_name,
        month: invoice.billing_month.strftime("%m/%Y"),
        raw_month: invoice.billing_month.strftime("%Y-%m"),
        due_date: invoice.due_date.strftime("%d/%m/%Y"),
        house_id: house.id
      ).deliver_later(tenant_users)
    end
  end
end
