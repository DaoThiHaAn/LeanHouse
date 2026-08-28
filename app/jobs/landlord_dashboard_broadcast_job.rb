class LandlordDashboardBroadcastJob < ApplicationJob
  queue_as :default

  def perform(house_id)
    LandlordDashboardBroadcaster.broadcast_now(house_id)
  end
end
