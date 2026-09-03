module AdminPortal
  class ServicesController < BaseController
    SERVICES_PER_PAGE = 10

    def index
      @house = House.active.includes(
        landlord: :user,
        floors: :rooms
      ).find(params[:house_id])

      @total_services_count = @house.services.count
      @services = @house.services
                        .name_sorted
                        .includes(service_variants: { rooms: :floor })
                        .page(params[:page])
                        .per(SERVICES_PER_PAGE)

      @total_house_rooms = @house.floors.sum { |f| f.rooms.reject(&:deleted?).count }
    end
  end
end
