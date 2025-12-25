module Otp
  extend ActiveSupport::Concern

  OTP_EXPIRY = 5.minutes

  def generate_otp!
    self.otp_code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    self.otp_sent_at = Time.current

    save!(validate: false)

    otp_code
  end


  def otp_expired?
    otp_sent_at.nil? || otp_sent_at < OTP_EXPIRY.ago
  end
end
