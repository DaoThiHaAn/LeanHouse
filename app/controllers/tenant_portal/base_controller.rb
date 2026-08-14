module TenantPortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :set_tenant_and_house

    private

    # To retrieve:
    # room: @tenant_stay.rental_unit.room
    # bed: @tenant_stay.rental_unit.bed&
    # floor: @tenant_stay.rental_unit.floor
    def set_tenant_and_house
      @tenant = current_user.tenant
      @tenant_stay = @tenant.tenant_stays
                            .where(checkout_at: nil)
                            .includes(rental_unit: :rentable)
                            .first

      return render("tenant_portal/shared/no_house", status: :ok) unless @tenant_stay

      @house = @tenant_stay.rental_unit.rentable.house
    end
  end
end
