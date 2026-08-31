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
      @house = House.active.includes(
        landlord: :user,
        floors: { rooms: [ :rental_unit, { beds: :rental_unit } ] },
        services: :service_variants
      ).find(params[:id])
    end
  end
end
