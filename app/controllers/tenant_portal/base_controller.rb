module TenantPortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_tenant!
    before_action :set_tenant_and_stay
    before_action :set_house
    before_action :require_linked_house!

    private

    def require_tenant!
      raise CanCan::AccessDenied unless current_user&.tenant?
    end

    def set_tenant_and_stay
      @tenant = current_user.tenant
      @tenant_stay = @tenant&.tenant_stays&.staying
                            &.includes(rental_unit: :rentable)
                            &.first
    end

    def set_house
      return unless @tenant_stay
      @house = @tenant_stay.rental_unit.rentable.house
    end

    def require_linked_house!
      render("tenant_portal/shared/no_house", status: :ok) unless @tenant_stay
    end
  end
end
