class OtpController < ApplicationController
  def input
    render "otp_input", locals: { tel: session[:pending_tel] }
  end

  def create
    result = PhoneVerification.new(params[:tel], params[:role]).request_otp
    session[:pending_tel] = result.user.tel
    redirect_to verify_otp_path
  end

  def verify
    tel = session[:pending_tel]

    unless tel
      redirect_to signup_path, alert: t("errors.session_expired")
      return
    end

    render "otp_input", locals: { tel: tel }
  end

  def confirm
    service = PhoneVerification.new(session[:pending_tel])
    result = service.verify_otp(params[:otp])

    if result.status == :verified
      log_in(result.user)
      redirect_to root_path
    else
      flash.now[:alert] = "Invalid or expired OTP"
      render :verify
    end
  end
end
