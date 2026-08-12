class AuthenticationController < ApplicationController
  def sign_up
    @user = User.new
  end

  def login_form
    return redirect_after_login if logged_in?

    @user = User.new
    render "authentication/log_in"
  end

  def log_out
    destroy_session
    flash[:notice] = t("success_messages.logout")
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

    return render_login_error(t("errors.tel_unregistered")) unless existing_acc
    return render_login_error(t("errors.inactive_acc")) unless existing_acc.active?
    return render_login_error(t("errors.wrong_pw")) unless existing_acc.authenticate(user_params[:password])

    log_in(existing_acc)
    flash[:notice] = t("success_messages.login")

    redirect_after_login
  end

  def handle_forgot_pw
    user_params = login_params
    existing_acc = User.find_acc(user_params[:tel], user_params[:role])

    return render_login_error(t("errors.tel_unregistered")) unless existing_acc
    return render_login_error(t("errors.inactive_acc")) unless existing_acc.active?

    result = PhoneVerification.new(
      tel: user_params[:tel],
      role: user_params[:role]
    ).create_otp(existing_acc)

    session[:pending_tel] = existing_acc.tel
    session[:pending_role] = existing_acc.role
    session[:is_reset_pw] = true
    flash[:development_otp] = result.otp if Rails.env.development?

    redirect_to otp_input_path, notice: t("success_messages.send_otp")
  end


  private

  def login_params
    params.require(:user).permit(:tel, :password, :role)
  end


  def redirect_after_login
    if current_user.landlord?
      redirect_to landlord_dashboard_path
    elsif current_user.tenant?
      redirect_to tenant_dashboard_path
    else
      redirect_to root_path
    end
  end


  def render_login_error(message)
    flash.now[:alert] = message

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        )
      end

      format.html do
        @user = User.new
        render :log_in, status: :unprocessable_entity
      end
    end
  end
end
