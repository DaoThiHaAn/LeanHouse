class OtpController < ApplicationController
  def input
    render "otp_input", locals: { tel: session[:pending_tel] }
  end

  def create
    result = PhoneVerification.new(params[:tel], params[:role]).request_otp
    session[:pending_tel] = result.user.tel
    redirect_to verify_otp_path
  end

  def resend
    verification = PhoneVerification.new(tel: session[:pending_tel], role: session[:pending_role])
    verification.resend_otp
    flash.now[:notice] = t("messages.resend_success")
    render "otp_input", locals: { tel: session[:pending_tel] }
  end

  def verify
    service = PhoneVerification.new(
      tel: session[:pending_tel],
      role: session[:pending_role]
    )

    Rails.logger.info "Input OTP in after form submission: #{params[:otp]}"

    result = service.verify_otp(params[:otp])

    respond_to do |format|
      message = ""
      case result.status
      when :verified
        session.delete(:pending_tel)
        session.delete(:pending_role)
        log_in(result.user)

        flash[:notice] = t("messages.signup_success")
        redirect_to root_path
        return

      when :otp_verification_failed
        message = t("messages.otp_failed")
      when :expired_otp
        message = t("errors.expired_otp")
      else
        message = t("messages.wrong_otp")
      end

      flash.now[:alert] = message
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        )
      end

      flash.discard
    end
  end
end
