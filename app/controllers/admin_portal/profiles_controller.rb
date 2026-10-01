# frozen_string_literal: true

module AdminPortal
  class ProfilesController < BaseController
    before_action :set_admin

    def edit
    end

    def update
      current_pw = profile_params[:current_password]
      new_pw = profile_params[:password]

      if current_pw.blank?
        @admin.errors.add(:current_password, :blank)
      elsif !@admin.authenticate(current_pw)
        @admin.errors.add(:current_password, :invalid)
      end

      if new_pw.blank?
        @admin.errors.add(:password, :blank)
      end

      if @admin.errors.any?
        return render :edit, status: :unprocessable_entity
      end

      if @admin.update(password: new_pw, password_confirmation: profile_params[:password_confirmation])
        redirect_to edit_admin_profile_path, notice: t("admin.profile.update_success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_admin
      @admin = current_admin
    end

    def profile_params
      params.require(:admin).permit(:current_password, :password, :password_confirmation)
    end
  end
end
