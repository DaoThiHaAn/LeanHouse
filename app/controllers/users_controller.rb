class UsersController < ApplicationController
  before_action :set_user, only: %i[ show edit update destroy ]

  # GET /users or /users.json
  def index
    @users = User.all
  end

  # GET /users/1 or /users/1.json
  def show
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users or /users.json
  def create
    phone_verification = PhoneVerification.new(user_params)
    result = phone_verification.request_signup_otp

    if result.status == :otp_sent
      session[:pending_tel]  = result.user.tel
      session[:pending_role] = result.user.role
      session[:is_reset_password] = false
      format.html { redirect_to login_path, notice: t("messages.reset_pw_success") }
    else
      @user = result.user
      # flash.now[:alert] = t("errors.signup_failed")
      render "authentication/sign_up", status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      context = session[:is_reset_pw] ? :pw_reset : nil

      @user.assign_attributes(user_params)

      if @user.save(context: context)
        if session[:is_reset_pw]
          clear_session_keys(:is_reset_pw, :verified_tel, :pending_role, :pending_tel)
          format.html { redirect_to login_path, notice: t("messages.user_update_pw_success") }
        else
          format.html { redirect_to @user, notice: t("messages.user_update_success"), status: :see_other }
          format.json { render :show, status: :ok, location: @user }
        end
      else
        if session[:is_reset_pw]
          format.html { render "authentication/reset_pw", status: :unprocessable_entity }
        else
          format.html { render :edit, status: :unprocessable_entity }
        end

        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end


  # DELETE /users/1 or /users/1.json
  def destroy
    @user.destroy!

    respond_to do |format|
      format.html { redirect_to users_path, notice: "User was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
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
