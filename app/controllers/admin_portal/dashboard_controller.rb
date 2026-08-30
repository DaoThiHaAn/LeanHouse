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

      @recent_users = User.kept.order(created_at: :desc).limit(8)
      @recent_houses = House.where(is_deleted: false).includes(:landlord).order(created_at: :desc).limit(5)
    end
  end
end
