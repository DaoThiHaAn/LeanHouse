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
    service = PhoneVerification.new(tel: session[:pending_tel], role: session[:pending_role])
    result = service.verify_otp(params[:otp])

    if result.status == :verified
      log_in(result.user)
      redirect_to root_path
    else
      flash[:alert] = t("errors.wrong_otp")
      render "otp_input", locals: { tel: session[:pending_tel] }
    end
  end
end
