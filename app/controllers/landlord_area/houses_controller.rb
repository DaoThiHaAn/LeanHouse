module LandlordArea
  class HousesController < ApplicationController
    # Entry point to checkout whether has created any house
    def entry
      if current_user.houses_count == 0
        render "entry"
      else
        # redirect_to
      end
    end

    def index
    end
  end
end
