class LandlordAssetStatsService
  def self.call(...)
    new(...).call
  end

  def initialize(house:)
    @house = house
  end

  def call
    counts = house.assets.group(:status).count
    normal_count = counts["normal"] || 0
    damaged_count = (counts["damaged"] || 0) + (counts["under_repair"] || 0)
    total_count = counts.values.sum
    total_price = house.assets.sum(:price) || 0

    {
      total_count: total_count,
      normal_count: normal_count,
      damaged_count: damaged_count,
      total_price: total_price
    }
  end

  private

  attr_reader :house
end
