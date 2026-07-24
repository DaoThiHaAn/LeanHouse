# A Base controller for all controllers in the landlord area.
# It sets up common functionality and filters that are shared across the landlord controllers.

# app/controllers/landlord_portal/base_controller.rb
module LandlordPortal
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :set_landlord, :require_house, :set_house, :set_other_houses

    private

    def set_landlord
      @landlord = current_user.landlord
    end

    # Redirect or render custom view if the landlord doesn't have any houses
    def require_house
      render "landlord_portal/shared/no_house", status: :ok if @landlord.houses_count.zero?
    end

    def set_house
      # Guard against missing house_id parameter (e.g. root landlord pages)
      return unless params[:house_id].present?

      @house = House.find(params[:house_id])
    end

    def set_other_houses
      return unless @house && @landlord

      @other_houses = @landlord.get_other_houses(@house.id).select(:id, :name)
    end
  end
end
