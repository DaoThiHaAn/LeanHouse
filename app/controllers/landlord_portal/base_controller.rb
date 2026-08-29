# A Base controller for all controllers in the landlord area.
# It sets up common functionality and filters that are shared across the landlord controllers.

# app/controllers/landlord_portal/base_controller.rb
module LandlordPortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_landlord!
    before_action :set_landlord, :require_house, :set_house
    before_action :authorize_house

    private

    def require_landlord!
      raise CanCan::AccessDenied unless current_user&.landlord?
    end

    def set_landlord
      @landlord = current_user.landlord
    end

    # Redirect or render custom view if the landlord doesn't have any houses
    def require_house
      return unless @landlord
      render "landlord_portal/shared/no_house", status: :ok if @landlord.houses_count.zero?
    end

    def set_house
      # Guard against missing or "all" house_id parameter (e.g. root landlord pages)
      return unless params[:house_id].present? && params[:house_id] != "all"

      @house = House.find(params[:house_id])
    end

    def authorize_house
      return unless @house
      authorize! :manage, @house
    end
  end
end
