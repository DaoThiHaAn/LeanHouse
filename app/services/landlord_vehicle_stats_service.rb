class LandlordVehicleStatsService
  def self.call(...)
    new(...).call
  end

  def initialize(house:)
    @house = house
  end

  def call
    counts = house.vehicles.group(:vehicle_type).count
    total_count = counts.values.sum

    type_counts = Vehicle.vehicle_types.keys.each_with_object({}) do |type, hash|
      hash[type] = counts[type] || 0
    end

    {
      total_count: total_count,
      type_counts: type_counts
    }
  end

  private

  attr_reader :house
end
