module AdminPortal
  class BaseController < ApplicationController
    layout "admin"

    before_action :authenticate_admin!
    helper_method :current_admin

    private

    def current_admin
      @current_admin ||= Admin.find_by(id: session[:admin_id], is_active: true) if session[:admin_id]
    end

    def authenticate_admin!
      return if current_admin

      redirect_to admin_login_path, alert: t("admin.auth.login_required", default: "Vui lòng đăng nhập với tài khoản Quản trị viên.")
    end

    def ensure_super_admin!
      return if current_admin&.super_admin?

      redirect_to admin_dashboard_path, alert: t("admin.auth.unauthorized", default: "Bạn không có quyền truy cập chức năng này.")
    end
  end
end
