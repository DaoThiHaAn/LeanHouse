class TenantPortal::ProfilesController < TenantPortal::BaseController
  skip_before_action :set_tenant_and_stay, :set_house, :require_linked_house!
  before_action :set_user

  def show
  end

  def edit
  end

  def update
    if @user.update(profile_params)
      redirect_to tenant_profile_path, notice: t("success_messages.user_updated")
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_avatar
    if @user.update(avatar_params)
      # Rails Active Storage auto purges the old attachment
      respond_to do |format|
        format.turbo_stream
        format.html { render partial: "avatar", locals: { user: @user } }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update_avatar, status: :unprocessable_entity }
        format.html { render partial: "avatar", locals: { user: @user }, status: :unprocessable_entity }
      end
    end
  end

  def new_tel
  end

  def change_tel
    new_tel = params[:tel]&.strip&.gsub(/\s+/, "")
    validation_user = User.find(@user.id)
    validation_user.tel = new_tel

    if validation_user.valid?(:change_tel)
      otp = @user.generate_otp!
      session[:pending_tel] = new_tel
      session[:pending_role] = @user.role
      session[:pending_new_tel] = new_tel
      session[:is_change_tel] = true
      flash[:development_otp] = otp if Rails.env.development?

      redirect_to otp_input_path, notice: t("success_messages.send_otp")
    else
      @user.errors.merge!(validation_user.errors)
      render :new_tel, status: :unprocessable_entity
    end
  end

  def change_password
    otp = @user.generate_otp!
    session[:pending_tel] = @user.tel
    session[:pending_role] = @user.role
    session[:is_reset_pw] = true
    flash[:development_otp] = otp if Rails.env.development?

    redirect_to otp_input_path, notice: t("success_messages.send_otp")
  end

  def check_delete
    @check = AccountDeletionCheck.call(@user)
    template = @check.can_delete? ? "account_delete_confirm" : "account_delete_blocked"
    render "layouts/shared_components/#{template}", locals: {
      delete_url: tenant_profile_path,
      resolve_stay_url: tenant_dashboard_path,
      resolve_requests_url: tenant_requests_path(status: "pending"),
      resolve_invoices_url: tenant_invoices_path(status: "pending")
    }
  end

  def destroy
    result = AccountDeletion.call(@user)
    if result.success?
      reset_session
      redirect_to root_path, notice: t("success_messages.account_deleted")
    else
      redirect_to tenant_profile_path, alert: t("errors.account_cant_deleted")
    end
  end

  private

  def set_user
    @user = current_user
  end

  def profile_params
    params.require(:user).permit(:fullname, :sex, :bday, :address)
  end

  def avatar_params
    params.require(:user).permit(:avatar)
  end
end
