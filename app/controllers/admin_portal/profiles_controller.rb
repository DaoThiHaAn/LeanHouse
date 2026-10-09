# frozen_string_literal: true

module AdminPortal
  class ProfilesController < BaseController
    before_action :set_admin

    def edit
    end

    def update
      @form_type = params[:form_type]

      if @form_type == "account_info"
        handle_account_update
      else
        handle_password_update
      end
    end

    private

    def set_admin
      @admin = current_admin
    end

    def handle_account_update
      unless @admin.super_admin?
        return redirect_to edit_admin_profile_path, alert: t("admin.profile.unauthorized_edit")
      end

      if @admin.update(account_params)
        redirect_to edit_admin_profile_path, notice: t("admin.profile.update_info_success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def handle_password_update
      @admin.assign_attributes(password_params)

      if @admin.save(context: :change_password)
        redirect_to edit_admin_profile_path, notice: t("admin.profile.update_success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def account_params
      params.require(:admin).permit(:fullname, :email)
    end

    def password_params
      params.require(:admin).permit(:current_password, :password, :password_confirmation)
    end
  end
end
