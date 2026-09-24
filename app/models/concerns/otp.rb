module Otp
  extend ActiveSupport::Concern

  OTP_EXPIRY = 5.minutes

  class << self
    def demo_mode?
      # Explicit override via SHOW_DEMO_OTP environment variable
      if ENV["SHOW_DEMO_OTP"].present?
        return ENV["SHOW_DEMO_OTP"].to_s.downcase.in?(%w[true 1 yes])
      end

      # If an actual SMS service gateway is explicitly enabled, disable demo sandbox
      return false if sms_service_enabled?

      # When no SMS service is configured, default to demo sandbox mode across all environments
      true
    end

    def sms_service_enabled?
      ENV["ENABLE_SMS_SERVICE"].to_s.downcase.in?(%w[true 1 yes]) ||
        ENV["SMS_API_KEY"].present? ||
        ENV["TWILIO_ACCOUNT_SID"].present? ||
        ENV["SPEEDSMS_API_KEY"].present? ||
        ENV["ESMS_API_KEY"].present?
    end
  end


  def generate_otp!
    self.otp_code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    self.otp_sent_at = Time.current

    save!(validate: false)

    otp_code
  end


  def otp_expired?
    otp_sent_at.nil? || otp_sent_at < OTP_EXPIRY.ago
  end

  def clear_otp
    self.otp_code = nil
    self.tel_verified_at = Time.current

    save!(validate: false)
  end
end
