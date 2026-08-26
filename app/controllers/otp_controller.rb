class OtpController < ApplicationController
  def input
    expires_at = calculate_expires_at
    render "otp_input", locals: { tel: session[:pending_tel], expires_at: expires_at }
  end

  def create
    result = PhoneVerification.new(params[:tel], params[:role]).request_otp
    session[:pending_tel] = result.user.tel
    redirect_to verify_otp_path
  end

  def resend
    if (session[:is_change_tel] || session[:is_reset_pw]) && logged_in?
      otp = current_user.generate_otp!
      flash[:notice] = t("success_messages.resend_otp")
      flash[:development_otp] = otp if Rails.env.development?
    else
      verification = PhoneVerification.new(tel: session[:pending_tel], role: session[:pending_role])
      result = verification.resend_otp
      flash[:notice] = t("success_messages.resend_otp")
      flash[:development_otp] = result.otp if Rails.env.development?
    end

    redirect_to otp_input_path
  end

  def verify
    if session[:is_change_tel] && logged_in?
      verify_change_tel
    else
      verify_signup_or_reset_pw
    end
  end

  private

  def calculate_expires_at
    user = current_pending_user
    (user&.otp_sent_at || Time.current) + Otp::OTP_EXPIRY
  end

  def current_pending_user
    if logged_in?
      current_user
    elsif session[:pending_tel].present? && session[:pending_role].present?
      User.kept.find_by(tel: session[:pending_tel], role: session[:pending_role])
    end
  end

  def verify_change_tel
    if current_user.otp_expired?
      return render_otp_error(t("errors.expired_otp"))
    end

    unless params[:otp].to_s.strip == current_user.otp_code
      return render_otp_error(t("errors.wrong_otp"))
    end

    new_tel = session[:pending_new_tel]

    begin
      ActiveRecord::Base.transaction do
        current_user.update!(
          tel: new_tel,
          tel_verified_at: Time.current,
          otp_code: nil
        )

        TelephoneChangedNotifier.with(
          new_tel: new_tel
        ).deliver(current_user)
      end

      clear_session_keys(:pending_role, :pending_tel, :pending_new_tel, :is_change_tel)

      flash[:notice] = t("success_messages.tel_updated")
      redirect_to current_user.landlord? ? landlord_profile_path : tenant_profile_path
    rescue ActiveRecord::RecordInvalid => e
      render_otp_error(e.record.errors.full_messages.join(", "))
    rescue StandardError => e
      Rails.logger.error("Change telephone failed: #{e.message}")
      render_otp_error(t("errors.otp_failed"))
    end
  end

  def verify_signup_or_reset_pw
    service = PhoneVerification.new(
      tel: session[:pending_tel],
      role: session[:pending_role]
    )

    Rails.logger.info "Input OTP in after form submission: #{params[:otp]}"

    result = service.verify_otp(params[:otp])

    case result.status
    when :verified
      if session[:is_reset_pw]
        session[:verified_tel] = session[:pending_tel]
        redirect_to reset_pw_path
      else
        clear_session_keys(:pending_role, :pending_tel)
        log_in(result.user)

        flash[:notice] = t("success_messages.signup")
        redirect_to root_path
      end
    when :otp_verification_failed
      render_otp_error(t("errors.otp_failed"))
    when :expired_otp
      render_otp_error(t("errors.expired_otp"))
    else
      render_otp_error(t("errors.wrong_otp"))
    end
  end

  def render_otp_error(message)
    flash.now[:alert] = message
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        )
      end

      format.html do
        expires_at = calculate_expires_at
        render "otp_input", locals: { tel: session[:pending_tel], expires_at: expires_at }, status: :unprocessable_entity
      end
    end
    flash.discard
  end
end
