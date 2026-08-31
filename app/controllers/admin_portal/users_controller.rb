module AdminPortal
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :toggle_active, :recycle_phone ]

    def index
      @role_filter = params[:role].presence || "all"
      @status_filter = params[:status].presence || "all"
      @query = params[:q].presence

      users = User.kept.with_attached_avatar

      users = users.where(role: @role_filter) if %w[landlord tenant].include?(@role_filter)

      case @status_filter
      when "active"
        users = users.where(is_active: true)
      when "inactive"
        users = users.where(is_active: false)
      end

      if @query
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(@query.strip)}%"
        users = users.where("fullname ILIKE ? OR tel ILIKE ? OR address ILIKE ?", sanitized, sanitized, sanitized)
      end

      @users = users.order(created_at: :desc)
    end

    def show
      if @user.landlord?
        @houses = House.where(landlord_id: @user.id, is_deleted: false).includes(:floors, :rooms)
      elsif @user.tenant?
        @current_stay = @user.tenant&.tenant_stays&.staying&.includes(rental_unit: :rentable)&.first
        @contracts = Contract.where(tenant_id: @user.id).order(created_at: :desc)
      end
    end

    def toggle_active
      new_status = !@user.is_active
      @user.update!(is_active: new_status)

      msg = new_status ? "Đã mở khóa tài khoản #{@user.fullname}." : "Đã khóa tài khoản #{@user.fullname}."
      redirect_back fallback_location: admin_users_path, notice: msg
    end

    def recycle_phone
      result = PhoneRecycling.new(@user, admin: current_admin, reason: params[:reason]).call

      if result.success?
        flash[:notice] = t("admin.users.recycle_success", tel: result.old_tel)
      else
        flash[:alert] = t("admin.users.recycle_failed", error: result.error)
      end

      redirect_back fallback_location: admin_user_path(@user)
    end

    private

    def set_user
      @user = User.kept.find(params[:id])
    end
  end
end
