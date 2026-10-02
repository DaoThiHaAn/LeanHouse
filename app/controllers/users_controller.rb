class UsersController < ApplicationController
  before_action :set_user, only: %i[ update ]

  # POST /users
  def create
    phone_verification = PhoneVerification.new(user_params)
    result = phone_verification.request_signup_otp

    if result.status == :otp_sent
      session[:pending_tel]  = result.user.tel
      session[:pending_role] = result.user.role
      session[:is_reset_password] = false
      flash[:development_otp] = result.otp if show_demo_otp?
      redirect_to otp_input_path, notice: t("success_messages.send_otp")
    else
      @user = result.user
      # flash.now[:alert] = t("errors.signup_failed")
      render "authentication/sign_up", status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1
  def update
    respond_to do |format|
      @user.assign_attributes(reset_pw_params)

      if @user.save(context: :pw_reset)
        was_logged_in = logged_in?
        target_path = if was_logged_in
                        current_user.landlord? ? landlord_profile_path : tenant_profile_path
        else
                        login_path
        end
        clear_session_keys(:is_reset_pw, :verified_tel, :pending_role, :pending_tel)
        format.html { redirect_to target_path, notice: t("success_messages.pw_updated") }
      else
        format.html { render "authentication/reset_pw", status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Ensure update only operates on the OTP-verified user in an active password reset flow.
    def set_user
      unless session[:is_reset_pw] && session[:verified_tel].present?
        redirect_to forgot_pw_path, alert: t("errors.session_expired")
        return
      end

      @user = if logged_in?
                current_user
      else
                User.kept.find_by(tel: session[:verified_tel], role: session[:pending_role])
      end

      unless @user && @user.id == params[:id].to_i
        redirect_to forgot_pw_path, alert: t("errors.session_expired")
      end
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit(
        :fullname,
        :tel,
        :password,
        :password_confirmation,
        :role,
        :address,
        :sex,
        :bday,
        :terms_accepted
      )
    end

    def reset_pw_params
      params.require(:user).permit(:password, :password_confirmation)
    end
end
