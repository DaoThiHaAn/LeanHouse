class LandlordDashboardStatsService
  def self.call(...)
    new(...).call
  end

  def initialize(landlord:, house_id: nil, target_date: Date.current)
    @landlord = landlord
    @house_id = house_id.presence && house_id != "all" ? house_id.to_i : nil
    @target_date = target_date
  end

  def call
    pending_reqs = LandlordDashboard::RequestStatsCalculator.call(target_houses)

    {
      target_date: target_date,
      house: selected_house,
      tenants_flow: LandlordDashboard::TenantFlowCalculator.call(target_houses, target_date),
      occupancy: LandlordDashboard::OccupancyCalculator.call(target_houses),
      pending_requests: pending_reqs,
      pending_requests_count: pending_reqs[:total],
      contracts: LandlordDashboard::ContractStatsCalculator.call(target_houses),
      invoices: LandlordDashboard::InvoiceStatsCalculator.call(target_houses, target_date),
      revenue: LandlordDashboard::RevenueStatsCalculator.call(
        landlord: landlord,
        target_houses: target_houses,
        house_id: house_id,
        target_date: target_date
      )
    }
  end

  private

  attr_reader :landlord, :house_id, :target_date

  def target_houses
    @target_houses ||= if house_id
      landlord.houses.where(id: house_id)
    else
      landlord.houses.active
    end
  end

  def selected_house
    @selected_house ||= landlord.houses.find_by(id: house_id) if house_id
  end
end
