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
      user.save!(context: :signup)
    end

   create_otp(user)

  rescue ActiveRecord::RecordInvalid
    Result.new(user, :invalid)
  end

  def create_otp(user)
    otp = user.generate_otp!
    Rails.logger.info "OTP for #{@tel}: #{otp}, role: #{user.role}, created_at #{user.otp_sent_at}"

    Result.new(user, :otp_sent)
  end

  def resend_otp
    user = User.kept.find_by(tel: @tel, role: @role, tel_verified_at: nil)
    create_otp(user)
  end

  def verify_otp(code)
    Rails.logger.info "Input OTP #{code}"

    user = User.kept.find_by!(tel: @tel, role: @role)

    return Result.new(user, :expired_otp) if user.otp_expired?
    return Result.new(user, :invalid_otp) unless code == user.otp_code

    begin
      ActiveRecord::Base.transaction do
        user.clear_otp

        if user.role == "landlord"
          Landlord.find_or_create_by!(id: user.id)
        else
          Tenant.find_or_create_by!(id: user.id)
        end
      end

      Result.new(user, :verified)

    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.error("OTP verification failed: #{e.message}")
      Result.new(user, :otp_verification_failed)
    end
  end

  private

  def normalize(tel)
    tel.to_s.strip.gsub(/\s+/, "")
  end
end
