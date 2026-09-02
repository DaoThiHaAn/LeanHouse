module AdminPortal
  class HousesController < BaseController
    def index
      @mode_filter = params[:mode].presence
      @query = params[:q].presence

      @houses = House.active
                     .includes(landlord: :user, floors: :rooms)
                     .search(@query)
                     .by_mode(@mode_filter)
                     .order(created_at: :desc)
    end

    def show
      @house = House.active.includes(landlord: :user).find(params[:id])
      @floors = @house.floors.pos_order
      @total_rooms_count = @house.rooms.active.count

      @floor_filter = params[:floor_id].presence
      @status_filter = params[:status].presence
      @query = params[:q].presence

      @rooms = HouseRoomsFilter.call(house: @house, params: params)
    end
  end
end
