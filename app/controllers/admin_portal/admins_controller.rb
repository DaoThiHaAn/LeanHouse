# frozen_string_literal: true

module AdminPortal
  class AdminsController < BaseController
    before_action :ensure_super_admin!
    before_action :set_admin, only: [ :edit, :update, :toggle_active ]
    before_action :ensure_support_admin!, only: [ :edit, :update ]

    def index
      @admins = Admin.order(role: :asc, created_at: :asc)
    end

    def new
      @admin = Admin.new(role: :support)
    end

    def create
      @admin = Admin.new(admin_params.merge(role: "support"))

      if @admin.save
        redirect_to admin_admins_path, notice: t("admin.admins.create_success", name: @admin.fullname)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @form_type = params[:form_type]

      if @form_type == "password"
        handle_password_update
      else
        handle_account_update
      end
    end

    def toggle_active
      if @admin == current_admin || @admin.super_admin?
        return redirect_to admin_admins_path, alert: t("admin.admins.cannot_lock_self")
      end

      new_status = !@admin.is_active
      @admin.update!(is_active: new_status)

      msg = new_status ? t("admin.admins.unlock_success", name: @admin.fullname) : t("admin.admins.lock_success", name: @admin.fullname)
      redirect_to admin_admins_path, notice: msg
    end

    private

    def ensure_support_admin!
      if @admin == current_admin
        redirect_to edit_admin_profile_path
      elsif @admin.super_admin?
        redirect_to admin_admins_path, alert: t("admin.admins.cannot_edit_super_admin")
      end
    end

    def handle_password_update
      new_pw = admin_params[:password]
      if new_pw.blank?
        @admin.errors.add(:password, :blank)
        return render :edit, status: :unprocessable_entity
      end

      if @admin.update(admin_params.slice(:password, :password_confirmation))
        redirect_to admin_admins_path, notice: t("admin.admins.reset_password_success", name: @admin.fullname)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def handle_account_update
      params_to_update = admin_params.except(:password, :password_confirmation).merge(role: "support")
      if admin_params[:password].present?
        params_to_update[:password] = admin_params[:password]
        params_to_update[:password_confirmation] = admin_params[:password_confirmation]
      end

      if @admin.update(params_to_update)
        redirect_to admin_admins_path, notice: t("admin.admins.update_success", name: @admin.fullname)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def set_admin
      @admin = Admin.find(params[:id])
    end

    def admin_params
      params.require(:admin).permit(:fullname, :email, :password, :password_confirmation, :role)
    end
  end
end
