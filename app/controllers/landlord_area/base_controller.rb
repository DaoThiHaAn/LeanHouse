module LandlordArea
  class BaseController < ApplicationController
    before_action :set_landlord
    before_action :require_house

    private

    def set_landlord
      @landlord = current_user.landlord
    end

    def require_house
      return if @landlord.houses_count > 0

      render "landlord_area/shared/no_house"
    end
  end
end
