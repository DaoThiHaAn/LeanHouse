module AdminPortal
  class DashboardController < BaseController
    def show
      @total_landlords = User.kept.where(role: :landlord).count
      @active_landlords = User.kept.where(role: :landlord, is_active: true).count
      @total_tenants = User.kept.where(role: :tenant).count
      @active_tenants = User.kept.where(role: :tenant, is_active: true).count

      @total_houses = House.where(is_deleted: false).count
      @room_houses = House.where(is_deleted: false, mode: "room").count
      @bed_houses = House.where(is_deleted: false, mode: "bed").count

      @total_rooms = Room.where(deleted: false).count
      @active_contracts = Contract.where("due_date >= ?", Date.current).where(end_date: nil).count

      current_month_range = Time.current.beginning_of_month..Time.current.end_of_month
      @new_users_this_month = User.kept.where(created_at: current_month_range).count
      @new_landlords_this_month = User.kept.where(role: :landlord, created_at: current_month_range).count
      @new_tenants_this_month = User.kept.where(role: :tenant, created_at: current_month_range).count

      @new_houses_this_month = House.where(is_deleted: false, created_at: current_month_range).count
      @new_room_houses_this_month = House.where(is_deleted: false, mode: "room", created_at: current_month_range).count
      @new_bed_houses_this_month = House.where(is_deleted: false, mode: "bed", created_at: current_month_range).count

      @recent_users = User.kept.order(created_at: :desc).limit(8)
      @recent_houses = House.where(is_deleted: false).includes(:landlord).order(created_at: :desc).limit(5)
    end
  end
end
