module Otp
  extend ActiveSupport::Concern

  OTP_EXPIRY = 5.minutes

  class << self
    def demo_mode?
      Rails.env.development? || ENV["SHOW_DEMO_OTP"].to_s.downcase.in?(%w[true 1 yes])
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
