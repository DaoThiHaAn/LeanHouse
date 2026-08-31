class PasswordRecovery
  MAX_ATTEMPTS = 3
  LOCKOUT_DURATION = 15.minutes

  Result = Struct.new(:success, :status, :user, :otp, :error_message, keyword_init: true) do
    def success?
      success == true
    end
  end

  def initialize(params = {})
    @params = params.to_h.symbolize_keys
    @tel = normalize(@params[:tel])
    @role = @params[:role]
    @fullname = @params[:fullname].to_s.squish
    @bday = @params[:bday].presence
  end

  def request_otp
    if locked_out?
      return Result.new(
        success: false,
        status: :rate_limited,
        error_message: I18n.t("errors.too_many_forgot_pw_attempts", minutes: lockout_minutes)
      )
    end

    user = User.find_acc(@tel, @role)

    unless user
      record_failed_attempt
      return Result.new(
        success: false,
        status: :tel_unregistered,
        error_message: I18n.t("errors.tel_unregistered")
      )
    end

    unless user.active?
      return Result.new(
        success: false,
        status: :inactive_acc,
        error_message: I18n.t("errors.inactive_acc")
      )
    end

    if @fullname.blank? || @bday.blank?
      return Result.new(
        success: false,
        status: :missing_fields,
        error_message: I18n.t("errors.missing_verification_fields")
      )
    end

    name_matched = user.fullname.to_s.squish.casecmp?(@fullname)
    bday_matched = user.bday.to_s == @bday.to_s

    unless name_matched && bday_matched
      record_failed_attempt
      remaining = remaining_attempts
      msg = if remaining > 0
        I18n.t("errors.identity_mismatch_with_remaining", remaining: remaining)
      else
        I18n.t("errors.too_many_forgot_pw_attempts", minutes: lockout_minutes)
      end

      return Result.new(
        success: false,
        status: :identity_mismatch,
        error_message: msg
      )
    end

    # All verified -> Reset attempts count & generate OTP
    clear_attempts
    verification = PhoneVerification.new(tel: @tel, role: @role)
    otp_result = verification.create_otp(user)

    Result.new(
      success: true,
      status: :otp_sent,
      user: user,
      otp: otp_result.otp
    )
  end

  def locked_out?
    current_attempts >= MAX_ATTEMPTS
  end

  def current_attempts
    Rails.cache.read(cache_key).to_i
  end

  def remaining_attempts
    [ MAX_ATTEMPTS - current_attempts, 0 ].max
  end

  private

  def lockout_minutes
    (LOCKOUT_DURATION / 60).to_i
  end

  def cache_key
    "pwd_recovery_attempts:#{@tel}:#{@role}"
  end

  def record_failed_attempt
    attempts = current_attempts + 1
    Rails.cache.write(cache_key, attempts, expires_in: LOCKOUT_DURATION)
  end

  def clear_attempts
    Rails.cache.delete(cache_key)
  end

  def normalize(tel)
    tel.to_s.strip.gsub(/\s+/, "")
  end
end
