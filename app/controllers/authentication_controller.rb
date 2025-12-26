class AuthenticationController < ApplicationController
  def sign_up
    @user = User.new
  end

  def login_form
    if logged_in?
      redirect_to root_path
      return
    end

    @user = User.new
    render "authentication/log_in"
  end

  def log_out
    destroy_session
    flash[:notice] = t("messages.logout_success")
    redirect_to root_path
  end

  def forgot_pw
    @user = User.new
  end

  def reset_pw
    tel = session[:verified_tel]

    unless tel
      redirect_to forgot_pw_path, alert: t("errors.session_expired")
      return
    end

    @user = User.kept.find_by(tel: tel, role: session[:pending_role])
  end


  def handle_log_in
    user_params = login_params
    existing_acc = User.find_acc(user_params[:tel], user_params[:role])
    message = nil

    if existing_acc.nil?
      message = t("errors.unregistered")
    elsif !existing_acc.active?
      message = t("errors.inactive_acc")
    elsif !existing_acc.authenticate(user_params[:password])
      message = t("errors.wrong_pw")
    else
      log_in(existing_acc)
      flash[:notice] = t("messages.login_success")
      # If you want to redirect after login, you can do it here
      return redirect_to root_path
    end

    # For invalid login: render flash in current view via Turbo
    flash.now[:alert] = message

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        )
      end

      format.html { render :new } # fallback for non-Turbo requests
    end
  end

  def handle_forgot_pw
    user_params = login_params
    existing_acc = User.find_acc(user_params[:tel], user_params[:role])
    message = nil

    if existing_acc.nil?
      message = t("errors.unregistered")
    elsif !existing_acc.active?
      message = t("errors.inactive_acc")
    else
      #
      result = PhoneVerification.new(
        tel: user_params[:tel],
        role: user_params[:role]
      )
      result.create_otp(existing_acc)
      session[:pending_tel] = existing_acc.tel
      session[:pending_role] = existing_acc.role
      session[:is_reset_pw] = true
      redirect_to otp_input_path, notice: t("messages.send_otp")
      return
    end

    flash.now[:alert] = message

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        )
      end

      format.html { render :new } # fallback for non-Turbo requests
    end
  end


  private

  def login_params
    params.require(:user).permit(:tel, :password, :role)
  end
end
