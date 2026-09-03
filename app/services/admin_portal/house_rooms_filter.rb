module AdminPortal
  class HouseRoomsFilter
    ROOMS_PER_PAGE = 15

    def self.call(...)
      new(...).call
    end

    def initialize(house:, params:)
      @house = house
      @query = params[:q]&.strip
      @floor_id = params[:floor_id].presence
      @status = params[:status].presence
      @page = params[:page]
    end

    def call
      scope = base_scope
      scope = apply_floor(scope)
      scope = apply_search(scope)
      scope = apply_status(scope)

      scope
        .includes(
          :floor,
          :rental_unit,
          { staying_tenants: :user },
          { beds: [ :rental_unit, { staying_tenant: :user } ] }
        )
        .order("floors.position ASC, rooms.name ASC")
        .page(page)
        .per(ROOMS_PER_PAGE)
    end

    private

    attr_reader :house, :query, :floor_id, :status, :page

    def base_scope
      Room.active.joins(:floor).where(floors: { house_id: house.id })
    end

    def apply_floor(scope)
      return scope if floor_id.blank?

      scope.where(rooms: { floor_id: floor_id })
    end

    def apply_search(scope)
      return scope if query.blank?

      q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      scope.where("unaccent(rooms.name) ILIKE unaccent(:q)", q: q)
    end

    def apply_status(scope)
      case status
      when "available"
        scope.where("rooms.tenants_count < rooms.max_slots")
      when "occupied"
        scope.where("rooms.tenants_count > 0")
      when "full"
        scope.where("rooms.tenants_count >= rooms.max_slots AND rooms.max_slots > 0")
      when "empty"
        scope.where("rooms.tenants_count = 0")
      else
        scope
      end
    end
  end
end
