class TenantPortal::ServicesController < TenantPortal::BaseController
  before_action :set_room

  def index
    @room_services = TenantServicesFilter.call(room: @room, params: params)
  end

  private

  def set_room
    @room = @tenant_stay.rental_unit.room
  end
end
