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
      flash[:development_otp] = result.otp if Rails.env.development?
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
      context = session[:is_reset_pw] ? :pw_reset : nil

      @user.assign_attributes(user_params)

      if @user.save(context: context)
        if session[:is_reset_pw]
          was_logged_in = logged_in?
          target_path = if was_logged_in
                          current_user.landlord? ? landlord_profile_path : tenant_profile_path
          else
                          login_path
          end
          clear_session_keys(:is_reset_pw, :verified_tel, :pending_role, :pending_tel)
          format.html { redirect_to target_path, notice: t("success_messages.user_update_pw_success") }
        else
          format.html { redirect_to root_path, notice: t("success_messages.user_updated"), status: :see_other }
        end
      else
        if session[:is_reset_pw]
          format.html { render "authentication/reset_pw", status: :unprocessable_entity }
        else
          format.html { redirect_to root_path, status: :unprocessable_entity }
        end

        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def user_params
      if session[:is_reset_pw]
        params.require(:user).permit(:password, :password_confirmation)
      else
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
    end
end
