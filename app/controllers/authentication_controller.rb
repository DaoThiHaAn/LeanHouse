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
    redirect_to root_path, status: :see_other
  end

  def forgot_pw
    @user = User.new
  end

  def reset_pw
    if logged_in?
      @user = current_user
    else
      tel = session[:verified_tel]

      unless tel
        redirect_to forgot_pw_path, alert: t("errors.session_expired")
        return
      end

      @user = User.kept.find_by(tel: tel, role: session[:pending_role])
    end
  end


  def handle_log_in
    user_params = login_params

    @user = User.new(
      user_params
    )

    unless @user.valid?(:login)
      # Rails.logger.debug "LOGIN VALIDATION ERRORS: #{@user.errors.full_messages}"
      return render "authentication/log_in", status: :unprocessable_entity
    end

    existing_acc = User.find_acc(user_params[:tel], user_params[:role])

    return render_login_error(t("errors.tel_unregistered")) unless existing_acc
    return render_login_error(t("errors.inactive_acc")) unless existing_acc.active?
    return render_login_error(t("errors.wrong_pw")) unless existing_acc.authenticate(user_params[:password])

    log_in(existing_acc)
    flash[:notice] = t("success_messages.login")

    redirect_after_login
  end

  def handle_forgot_pw
    result = PasswordRecovery.new(forgot_pw_params).request_otp

    if result.success?
      session[:pending_tel] = result.user.tel
      session[:pending_role] = result.user.role
      session[:is_reset_pw] = true
      flash[:development_otp] = result.otp if Rails.env.development?

      redirect_to otp_input_path, notice: t("success_messages.send_otp")
    else
      render_auth_error(result.error_message, template: :forgot_pw)
    end
  end


  private

  def login_params
    params.require(:user).permit(:tel, :password, :role)
  end

  def forgot_pw_params
    params.require(:user).permit(:tel, :role, :fullname, :bday)
  end


  def redirect_after_login
    target = if current_user.landlord?
      landlord_dashboard_path
    elsif current_user.tenant?
      tenant_dashboard_path
    else
      root_path
    end

    redirect_to target, status: :see_other
  end


  def render_auth_error(message, template: :log_in)
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
        render template, status: :unprocessable_entity
      end
    end
  end

  def render_login_error(message)
    render_auth_error(message, template: :log_in)
  end
end
