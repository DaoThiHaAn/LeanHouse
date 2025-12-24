class PhoneVerification
  Result = Struct.new(:user, :status)

  def initialize(user_params = {})
    @params = user_params.to_h.symbolize_keys
    @tel = normalize(@params[:tel])
    @role = @params[:role]
  end

  def request_signup_otp
    # Find the record that hasnt been verified
    user = User.kept.find_by(tel: @tel, role: @role, tel_verified_at: nil)

    if user.present?
      user.update!(@params)
    else
      user = User.new(@params)
      user.save!
    end

    otp = user.generate_otp!
    Rails.logger.info "OTP for #{@tel}: #{otp}"

    Result.new(user, :otp_sent)
  rescue ActiveRecord::RecordInvalid
    Result.new(user, :invalid)
  end

  def verify_otp(code)
    user = User.kept.find_by!(tel: @tel, role: @role)

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
