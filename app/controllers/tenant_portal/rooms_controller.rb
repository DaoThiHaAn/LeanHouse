class TenantPortal::RoomsController < TenantPortal::BaseController
  def show
    @landlord = @house.landlord.user
    @rental_unit = @tenant_stay.rental_unit
    @room = @rental_unit.room
    @assets = @room.assets.sorted
    @roommates = @room.formatted_roommates(@house, @tenant.id)
  end
end
