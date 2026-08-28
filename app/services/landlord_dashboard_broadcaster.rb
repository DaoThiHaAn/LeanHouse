class LandlordDashboardBroadcaster
  def self.broadcast_later(house_id)
    return if house_id.blank?
    LandlordDashboardBroadcastJob.perform_later(house_id)
  end

  def self.broadcast_now(house_id)
    return if house_id.blank?

    house = House.includes(:landlord).find_by(id: house_id)
    return unless house&.landlord

    landlord = house.landlord

    # 1. Broadcast update to the specific house's dashboard stream
    stats_house = LandlordDashboardStatsService.call(landlord: landlord, house_id: house.id)
    Turbo::StreamsChannel.broadcast_replace_to(
      landlord, house, :dashboard,
      target: "dashboard_stats",
      partial: "landlord_portal/dashboards/stats_grid",
      locals: {
        stats: stats_house,
        selected_house: house
      }
    )

    # 2. Broadcast update to the "all houses" dashboard stream
    stats_all = LandlordDashboardStatsService.call(landlord: landlord, house_id: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      landlord, :all, :dashboard,
      target: "dashboard_stats",
      partial: "landlord_portal/dashboards/stats_grid",
      locals: {
        stats: stats_all,
        selected_house: nil
      }
    )
  end
end
