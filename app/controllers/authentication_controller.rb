class AuthenticationController < ApplicationController
  def sign_up
    @user = User.new
  end

  def log_in
  end

  def log_out
    # TODO
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
  end
end
