class TenantPortal::ProfilesController < TenantPortal::BaseController
  before_action :set_user

  def show
  end

  def edit
  end

  def update
  end

  def update_avatar
    if @user.update(avatar_params)
      # Rails Active Storage auto purges the old attachment
      render partial: "avatar", locals: { user: @user }
    else
      render partial: "avatar", locals: { user: @user }, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def avatar_params
    params.require(:user).permit(:avatar)
  end
end
