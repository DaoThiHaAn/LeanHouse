module AdminPortal
  class ServicesController < BaseController
    def index
      @house = House.active.includes(
        landlord: :user,
        floors: :rooms,
        services: {
          service_variants: {
            rooms: :floor
          }
        }
      ).find(params[:house_id])

      @services = @house.services.name_sorted
      @total_house_rooms = @house.floors.sum { |f| f.rooms.reject(&:deleted?).count }
    end
  end
end
