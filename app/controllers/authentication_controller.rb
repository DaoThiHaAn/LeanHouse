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
  end

  def reset_pw
    tel = session[:verified_tel]

    unless tel
      redirect_to forgot_pw_path, alert: t("errors.session_expired")
      return
    end

    @user = User.find_by(tel: tel)

    unless @user
      reset_session
      redirect_to forgot_pw_path, alert: t("errors.user_not_found")
    end
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


  private

  def login_params
    params.require(:user).permit(:tel, :password, :role)
  end
end
