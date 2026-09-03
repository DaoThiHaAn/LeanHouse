module AdminPortal
  class AdminsController < BaseController
    before_action :ensure_super_admin!
    before_action :set_admin, only: [ :edit, :update, :toggle_active ]

    def index
      @admins = Admin.order(role: :asc, created_at: :asc)
    end

    def new
      @admin = Admin.new(role: :support)
    end

    def create
      @admin = Admin.new(admin_params)

      if @admin.save
        redirect_to admin_admins_path, notice: t("admin.admins.create_success", name: @admin.fullname)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      params_to_update = admin_params
      if params_to_update[:password].blank?
        params_to_update = params_to_update.except(:password, :password_confirmation)
      end

      if @admin.super_admin? && params_to_update[:role].present? && params_to_update[:role] != "super_admin" && Admin.super_admin.active.count <= 1
        flash.now[:alert] = t("admin.admins.cannot_demote_last_super_admin")
        return render :edit, status: :unprocessable_entity
      end

      if @admin.update(params_to_update)
        redirect_to admin_admins_path, notice: t("admin.admins.update_success", name: @admin.fullname)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def toggle_active
      if @admin == current_admin
        return redirect_to admin_admins_path, alert: t("admin.admins.cannot_lock_self")
      end

      if @admin.super_admin? && @admin.is_active? && Admin.super_admin.active.count <= 1
        return redirect_to admin_admins_path, alert: t("admin.admins.cannot_lock_last_super_admin")
      end

      new_status = !@admin.is_active
      @admin.update!(is_active: new_status)

      msg = new_status ? t("admin.admins.unlock_success", name: @admin.fullname) : t("admin.admins.lock_success", name: @admin.fullname)
      redirect_to admin_admins_path, notice: msg
    end

    private

    def set_admin
      @admin = Admin.find(params[:id])
    end

    def admin_params
      params.require(:admin).permit(:fullname, :email, :password, :password_confirmation, :role)
    end
  end
end
