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
      user.update!(@params, context: :signup)
    else
      user = User.new(@params)
      user.save!(context: :signup)
    end

   create_otp(user)

  rescue ActiveRecord::RecordInvalid
    Result.new(user, :invalid)
  end

  def create_otp(user)
    otp = user.generate_otp!
    # otp_created_at = user.get_otp_sent_at
    Rails.logger.info "OTP for #{@tel}: #{otp}, role: #{user.role}, created_at #{user.otp_sent_at}"

    Result.new(user, :otp_sent)
  end

  def resend_otp
    user = User.kept.find_by(tel: @tel, role: @role, tel_verified_at: nil)
    create_otp(user)
  end

  def verify_otp(code)
    user = User.kept.find_by!(tel: @tel, role: @role)

    if user.verify_otp!(code)
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
