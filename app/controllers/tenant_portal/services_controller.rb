class TenantPortal::ServicesController < TenantPortal::BaseController
  def index
    @room_services = @tenant_stay.rental_unit.room.room_services.includes(service_variant: :service)
  end
end
