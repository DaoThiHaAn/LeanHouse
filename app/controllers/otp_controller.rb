class OtpController < ApplicationController
  def new
    render "otp_input", locals: { tel: "0914565109" }
  end

  def create
    result = TelephoneVerification.new(params[:tel]).request_otp
    session[:pending_tel] = result.user.tel
    redirect_to verify_otp_path
  end

  def verify
  end

  def confirm
    service = TelephoneVerification.new(session[:pending_tel])
    result = service.verify_otp(params[:otp])

    if result.status == :verified
      log_in(result.user)
      redirect_to choose_role_path
    else
      flash.now[:alert] = "Invalid or expired OTP"
      render :verify
    end
  end
end
