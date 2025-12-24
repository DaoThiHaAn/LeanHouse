module Otp
  extend ActiveSupport::Concern

  OTP_EXPIRY = 5.minutes

  def generate_otp!
    otp = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")

    update!(
      otp_code: otp,
      otp_sent_at: Time.current,
    )

    otp
  end

  def verify_otp!(code)
    return false if otp_expired?

    otp_code == code
  end

  def otp_expired?
    otp_sent_at.nil? || otp_sent_at < OTP_EXPIRY.ago
  end
end
