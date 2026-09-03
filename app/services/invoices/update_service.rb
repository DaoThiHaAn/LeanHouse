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
      return false unless invoice.update(params)

      sync_item_dates_if_needed
      regenerate_transfer_note
      deliver_notifications

      true
    end

    private

    attr_reader :invoice, :house, :params

    def sync_item_dates_if_needed
      if params[:start_date].present? || params[:end_date].present?
        invoice.invoice_items.update_all(
          start_date: invoice.start_date,
          end_date: invoice.end_date
        )
      end
    end

    def regenerate_transfer_note
      invoice.update_column(
        :transfer_note,
        TransferNoteBuilder.build(house.transfer_note_template, invoice)
      )
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
