module Webhooks
  class PayosController < ActionController::API
    def receive
      # Handle ping or empty test payloads from payOS dashboard
      data = params[:data]
      if data.blank?
        return render json: { message: "payOS Webhook received (ping/empty)" }, status: :ok
      end

      # Parse orderCode
      data_hash = data.respond_to?(:to_unsafe_h) ? data.to_unsafe_h : data.to_h
      order_code = data_hash[:orderCode] || data_hash["orderCode"]

      if order_code.blank?
        return render json: { message: "payOS Webhook received (no orderCode)" }, status: :ok
      end

      invoice = Invoice.find_by(payos_order_code: order_code) || Invoice.find_by(id: order_code)
      unless invoice
        Rails.logger.warn("[PayosWebhook] Invoice not found for orderCode: #{order_code}")
        return render json: { message: "Invoice not found, ignored" }, status: :ok
      end

      bank_account = invoice.bank_account
      signature = params[:signature].to_s

      # Verify HMAC signature
      is_valid = PayosService.verify_webhook_data(data_hash, signature, bank_account&.payos_checksum_key)
      unless is_valid
        Rails.logger.warn("[PayosWebhook] Invalid signature for invoice ##{invoice.id}")
        return render json: { error: "Invalid signature" }, status: :bad_request
      end

      # If signature is valid, mark invoice as paid if not already paid
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

        invoice.update_columns(payos_status: "PAID")

        # Broadcast live Turbo Stream to anyone viewing the invoice
        Turbo::StreamsChannel.broadcast_replace_to(
          [invoice, :payment],
          target: "invoice_detail_card_#{invoice.id}",
          partial: "layouts/shared_components/invoice_detail_card",
          locals: { invoice: invoice.reload, bank_account: invoice.bank_account }
        )
      end

      render json: { success: true, message: "Payment processed successfully" }, status: :ok
    rescue StandardError => e
      Rails.logger.error("[PayosWebhook] Error handling webhook: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      render json: { error: e.message }, status: :internal_server_error
    end
  end
end
