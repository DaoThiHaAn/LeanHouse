# A Base controller for all controllers in the landlord area.
# It sets up common functionality and filters that are shared across the landlord controllers.

module LandlordPortal
  class BaseController < ApplicationController
    before_action :authenticate_user! # Devise method to ensure the user is logged in.
    before_action :set_landlord
    before_action :require_house # Ensure the landlord has at least one house, except for the show action.

    load_and_authorize_resource # Cancancan method to load and authorize resources based on the current user's abilities.

    private

    def set_landlord
      @landlord = current_user.landlord
    end

    def require_house
      return if @landlord.houses_count > 0

      render "landlord_portal/shared/no_house"
    end

    # Let children controllers use
    def set_house
      @house = House.find(params.expect(:house_id))
    end
  end
end
