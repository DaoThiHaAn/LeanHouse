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
      redirect_to otp_input_path, notice: t("messages.send_otp")
    else
      @user = result.user
      # flash.now[:alert] = t("errors.signup_failed")
      render "authentication/sign_up", status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to @user, notice: "User was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
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
