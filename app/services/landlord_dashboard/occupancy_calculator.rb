module LandlordDashboard
  class OccupancyCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(target_houses)
      @target_houses = target_houses
    end

    def call
      house_ids = target_houses.select(:id)
      return { rate: 0.0, occupied: 0, total: 0 } if house_ids.empty?

      rooms_scope = Room.joins(:floor).where(deleted: false, floors: { house_id: house_ids })

      stats = rooms_scope.select(
        "COALESCE(SUM(rooms.max_slots), 0) AS total_capacity,
         COALESCE(SUM(rooms.tenants_count), 0) AS total_occupied"
      ).take

      total_capacity = stats&.total_capacity.to_i
      total_occupied = stats&.total_occupied.to_i
      rate = total_capacity.zero? ? 0.0 : ((total_occupied.to_f / total_capacity) * 100).round(1)

      {
        rate: rate,
        occupied: total_occupied,
        total: total_capacity
      }
    end

    private

    attr_reader :target_houses
  end
end
