# frozen_string_literal: true

module Payos
  class ProcessWebhookService
    def self.call(params)
      new(params).call
    end

    def initialize(params)
      @params = params
    end

    def call
      data = @params[:data]
      if data.blank?
        return { json: { message: I18n.t("invoice.payos.webhook.ping_received", default: "payOS Webhook received (ping/empty)") }, status: :ok }
      end

      data_hash = data.respond_to?(:to_unsafe_h) ? data.to_unsafe_h : data.to_h
      order_code = data_hash[:orderCode] || data_hash["orderCode"]

      if order_code.blank?
        return { json: { message: I18n.t("invoice.payos.webhook.no_order_code", default: "payOS Webhook received (no orderCode)") }, status: :ok }
      end

      payment_order = PaymentOrder.find_by(order_code: order_code)
      invoice = payment_order&.invoice || Invoice.find_by(id: order_code)

      unless invoice
        Rails.logger.warn("[PayosWebhook] Invoice not found for orderCode: #{order_code}")
        return { json: { message: I18n.t("invoice.payos.webhook.invoice_not_found", default: "Invoice not found, ignored") }, status: :ok }
      end

      bank_account = invoice.bank_account
      signature = @params[:signature].to_s

      is_valid = PayosService.verify_webhook_data(data_hash, signature, bank_account&.payos_checksum_key)
      unless is_valid
        Rails.logger.warn("[PayosWebhook] Invalid signature for invoice ##{invoice.id}")
        return { json: { error: I18n.t("invoice.payos.webhook.invalid_signature", default: "Invalid signature") }, status: :bad_request }
      end

      if invoice.pending? || invoice.overdue?
        reference = data_hash[:reference] || data_hash["reference"]
        payment_note = I18n.t("invoice.payos.auto_paid_note", ref: reference, default: "Tự động gạch nợ qua payOS (Mã GD: #{reference})")

        Invoices::MarkPaidService.call(
          invoice: invoice,
          paid_by: nil,
          params: {
            payment_method: "transfer",
            note: payment_note
          }
        )

        payment_order&.update!(status: "PAID")

        Turbo::StreamsChannel.broadcast_replace_to(
          [ invoice, :payment ],
          target: "invoice_detail_card_#{invoice.id}",
          partial: "layouts/shared_components/invoice_detail_card",
          locals: { invoice: invoice.reload, bank_account: invoice.bank_account }
        )
      end

      { json: { success: true, message: I18n.t("invoice.payos.webhook.success", default: "Payment processed successfully") }, status: :ok }
    rescue StandardError => e
      Rails.logger.error("[PayosWebhook] Error handling webhook: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      { json: { error: e.message }, status: :internal_server_error }
    end
  end
end
