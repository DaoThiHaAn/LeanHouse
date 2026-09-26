module AdminPortal
  class HousesController < BaseController
    HOUSES_PER_PAGE = 15

    def index
      @mode_filter = params[:mode].presence
      @status_filter = params[:status].presence || "all"
      @query = params[:q].presence

      houses = House.includes(landlord: :user, floors: :rooms)
                    .search(@query)
                    .by_mode(@mode_filter)

      case @status_filter
      when "active"
        houses = houses.active
      when "deleted"
        houses = houses.deleted
      end

      @houses = houses.order(created_at: :desc).page(params[:page]).per(HOUSES_PER_PAGE)
    end

    def show
      @house = House.includes(landlord: :user).find(params[:id])
      @floors = @house.floors.pos_order
      @total_rooms_count = @house.rooms.active.count

      @floor_filter = params[:floor_id].presence
      @status_filter = params[:status].presence
      @query = params[:q].presence
      @page = params[:page].presence

      @rooms = HouseRoomsFilter.call(house: @house, params: params)
    end
  end
end
