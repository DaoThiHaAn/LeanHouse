class PhoneVerification
  Result = Struct.new(:user, :status)

  def initialize(tel)
    @tel = normalize(tel)
  end

  def request_otp
    user = User.kept.find_or_initialize_by(tel: @tel)
    user.save! if user.new_record?

    otp = user.generate_otp!
    Rails.logger.info "OTP for #{@tel}: #{otp}"

    Result.new(user, :otp_sent)
  end

  def verify_otp(code)
    user = User.kept.find_by!(tel: @tel)

    if user.verify_otp!(code)
      user.update!(
        tel_verified_at: Time.current,
        otp_code: nil
      )
      Result.new(user, :verified)
    else
      Result.new(user, :invalid_otp)
    end
  end

  private

  def normalize(tel)
    tel.to_s.strip.gsub(/\s+/, "")
  end
end
