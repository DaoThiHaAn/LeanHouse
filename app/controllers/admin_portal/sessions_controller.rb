module AdminPortal
  class SessionsController < ApplicationController
    layout "admin_auth"

    def new
      redirect_to admin_dashboard_path if current_admin
    end

    def create
      email = params[:email]&.strip&.downcase
      password = params[:password]

      if email.blank? || password.blank?
        flash.now[:alert] = t("admin.auth.invalid_inputs", default: "Vui lòng nhập đầy đủ Email và Mật khẩu.")
        return render :new, status: :unprocessable_entity
      end

      admin = Admin.find_by(email: email)

      if admin.nil? || !admin.authenticate(password)
        flash.now[:alert] = t("admin.auth.wrong_credentials", default: "Email hoặc mật khẩu không chính xác.")
        return render :new, status: :unprocessable_entity
      end

      unless admin.active?
        flash.now[:alert] = t("admin.auth.account_locked", default: "Tài khoản quản trị viên này đã bị vô hiệu hóa.")
        return render :new, status: :forbidden
      end

      admin.update_column(:last_login_at, Time.current)
      session[:admin_id] = admin.id

      redirect_to admin_dashboard_path, notice: t("admin.auth.login_success", default: "Đăng nhập thành công vào Hệ thống Quản trị.")
    end

    def destroy
      session.delete(:admin_id)
      redirect_to admin_login_path, notice: t("admin.auth.logout_success", default: "Đã đăng xuất khỏi Hệ thống Quản trị.")
    end

    private

    def current_admin
      @current_admin ||= Admin.find_by(id: session[:admin_id], is_active: true) if session[:admin_id]
    end
    helper_method :current_admin
  end
end
