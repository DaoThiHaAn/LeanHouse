require "net/http"
require "json"
require "uri"
require "openssl"

class PayosService
  PAYOS_API_URL = "https://api-merchant.payos.vn/v2/payment-requests".freeze

  # Generate HMAC-SHA256 signature for any hash of data by sorting keys alphabetically
  def self.create_signature(data, checksum_key)
    return nil if data.blank? || checksum_key.blank?

    sorted_keys = data.keys.map(&:to_s).sort
    data_string = sorted_keys.map do |k|
      val = data[k] || data[k.to_sym]
      "#{k}=#{val}"
    end.join("&")

    OpenSSL::HMAC.hexdigest("SHA256", checksum_key, data_string)
  end

  # Verify signature received in payOS webhook
  def self.verify_webhook_data(data, signature, checksum_key)
    return false if data.blank? || signature.blank? || checksum_key.blank?

    expected_sig = create_signature(data, checksum_key)
    return false if expected_sig.blank?

    ActiveSupport::SecurityUtils.secure_compare(expected_sig.downcase, signature.to_s.downcase)
  rescue StandardError => e
    Rails.logger.error("[PayosService] Webhook verification failed: #{e.message}")
    false
  end

  # Resolve base application URL from environment, request host, or routing defaults
  def self.base_app_url(host: nil)
    if ENV["APP_HOST"].present?
      h = ENV["APP_HOST"].to_s.strip
      return h.chomp("/") if h.start_with?("http://", "https://")
      protocol = Rails.env.production? ? "https" : "http"
      return "#{protocol}://#{h}".chomp("/")
    end

    if host.present?
      h = host.to_s.strip
      return h.chomp("/") if h.start_with?("http://", "https://")
      protocol = Rails.env.production? ? "https" : "http"
      return "#{protocol}://#{h}".chomp("/")
    end

    default_host = Rails.application.routes.default_url_options[:host]
    if default_host.present?
      protocol = Rails.env.production? ? "https" : "http"
      port = Rails.application.routes.default_url_options[:port]
      port_str = port.present? && ![ 80, 443 ].include?(port.to_i) ? ":#{port}" : ""
      return "#{protocol}://#{default_host}#{port_str}".chomp("/")
    end

    "http://localhost:3000"
  end

  # Resolve Webhook URL for payOS (prioritizes PAYOS_WEBHOOK_URL, then request, then base_app_url)
  def self.webhook_url(request = nil)
    return ENV["PAYOS_WEBHOOK_URL"].strip if ENV["PAYOS_WEBHOOK_URL"].present?

    if request.present? && request.respond_to?(:base_url) && request.base_url.present?
      return "#{request.base_url.chomp('/')}/webhooks/payos"
    end

    "#{base_app_url}/webhooks/payos"
  end

  # Create payment link for an invoice via payOS API
  def self.create_payment_link(invoice, host: nil)
    bank_account = invoice.bank_account
    return { success: false, error: I18n.t("invoice.payos.webhook.unconfigured_bank", default: "Bank account not configured for payOS") } unless bank_account&.payos_configured?

    order = invoice.ensure_payos_order!
    order_code = order.order_code
    amount = invoice.total_amount.to_i
    description = invoice.payos_transfer_description
    base_url = base_app_url(host: host)
    return_url = "#{base_url}/payments/payos/return/#{invoice.id}"
    cancel_url = "#{base_url}/payments/payos/cancel/#{invoice.id}"

    # Data to sign for payment request
    request_data = {
      "amount" => amount,
      "cancelUrl" => cancel_url,
      "description" => description,
      "orderCode" => order_code,
      "returnUrl" => return_url
    }

    signature = create_signature(request_data, bank_account.payos_checksum_key)

    body = request_data.merge("signature" => signature)

    uri = URI(PAYOS_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["x-client-id"] = bank_account.payos_client_id
    request["x-api-key"] = bank_account.payos_api_key
    request.body = body.to_json

    response = http.request(request)
    res_data = JSON.parse(response.body) rescue {}

    if response.is_a?(Net::HTTPSuccess) && res_data["code"] == "00" && res_data["data"].present?
      data = res_data["data"]
      order.update!(
        payment_link_id: data["paymentLinkId"],
        checkout_url: data["checkoutUrl"],
        qr_code: data["qrCode"],
        status: data["status"] || "PENDING",
        metadata: data
      )
      { success: true, data: data }
    else
      err_msg = res_data["desc"] || "Failed to create payOS payment link (HTTP #{response.code})"
      Rails.logger.warn("[PayosService] API error for invoice ##{invoice.id}: #{err_msg}")
      { success: false, error: err_msg, response: res_data }
    end
  rescue StandardError => e
    Rails.logger.error("[PayosService] Exception creating payment link: #{e.message}")
    { success: false, error: e.message }
  end

  # Cancel payment link for an invoice via payOS API
  def self.cancel_payment_link(invoice, reason: nil)
    bank_account = invoice.bank_account
    return { success: false, error: "Bank account not configured for payOS" } unless bank_account&.payos_configured?

    order = invoice.payos_order
    return { success: true, message: "No payOS order to cancel" } unless order && (order.payment_link_id.present? || order.order_code.present?)

    target_id = order.order_code || order.payment_link_id
    reason_text = reason.presence || "Hóa đơn đã bị hủy trên hệ thống"

    uri = URI("#{PAYOS_API_URL}/#{target_id}/cancel")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 10
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["x-client-id"] = bank_account.payos_client_id
    request["x-api-key"] = bank_account.payos_api_key
    request.body = { "cancellationReason" => reason_text }.to_json

    response = http.request(request)
    res_data = JSON.parse(response.body) rescue {}

    if response.is_a?(Net::HTTPSuccess) && res_data["code"] == "00"
      order.update!(status: "CANCELLED")
      { success: true, data: res_data["data"] }
    else
      err_msg = res_data["desc"] || "Failed to cancel payOS payment link (HTTP #{response.code})"
      Rails.logger.warn("[PayosService] API cancel error for invoice ##{invoice.id}: #{err_msg}")
      order.update!(status: "CANCELLED")
      { success: false, error: err_msg, response: res_data }
    end
  rescue StandardError => e
    Rails.logger.error("[PayosService] Exception cancelling payment link: #{e.message}")
    order&.update!(status: "CANCELLED") rescue nil
    { success: false, error: e.message }
  end

  # Fetch payment link info from payOS API
  def self.fetch_payment_link_info(order_code_or_id, bank_account)
    return { success: false, error: "Bank account not configured for payOS" } unless bank_account&.payos_configured?
    return { success: false, error: "No order code or payment link ID" } if order_code_or_id.blank?

    uri = URI("#{PAYOS_API_URL}/#{order_code_or_id}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request["x-client-id"] = bank_account.payos_client_id
    request["x-api-key"] = bank_account.payos_api_key

    response = http.request(request)
    res_data = JSON.parse(response.body) rescue {}

    if response.is_a?(Net::HTTPSuccess) && res_data["code"] == "00" && res_data["data"].present?
      { success: true, data: res_data["data"] }
    else
      err_msg = res_data["desc"] || "Failed to fetch payOS payment info (HTTP #{response.code})"
      { success: false, error: err_msg, response: res_data }
    end
  rescue StandardError => e
    Rails.logger.error("[PayosService] Exception fetching payment link info: #{e.message}")
    { success: false, error: e.message }
  end

  # Reconcile invoice payment with payOS if paid on gateway but pending in LeanHouse
  def self.reconcile_payment!(invoice)
    return invoice if invoice.paid?
    return invoice unless invoice.payos_configured?

    order = invoice.payos_order
    target_id = order&.order_code || order&.payment_link_id
    return invoice if target_id.blank?

    res = fetch_payment_link_info(target_id, invoice.bank_account)
    if res[:success] && res[:data]["status"] == "PAID"
      data = res[:data]
      reference = data["transactions"]&.last&.dig("reference") || data["id"]
      payment_note = I18n.t("invoice.payos.auto_paid_note", ref: reference, default: "Tự động gạch nợ qua payOS (Mã GD: #{reference})")

      Invoices::MarkPaidService.call(
        invoice: invoice,
        paid_by: nil,
        params: {
          payment_method: "transfer",
          note: payment_note
        }
      )
      order&.update!(status: "PAID")
      invoice.reload
    end
    invoice
  rescue StandardError => e
    Rails.logger.error("[PayosService] Reconcile error: #{e.message}")
    invoice
  end
end
