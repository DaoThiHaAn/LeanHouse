# frozen_string_literal: true

class LandlordRequestBadgeBroadcaster
  def self.broadcast_now(landlord)
    return unless landlord

    count = landlord.requests.pending.count
    Turbo::StreamsChannel.broadcast_replace_to(
      landlord, :requests,
      target: "landlord_requests_nav_badge",
      partial: "landlord_portal/requests/nav_badge",
      locals: { count: count }
    )
  rescue StandardError => e
    Rails.logger.error("[LandlordRequestBadgeBroadcaster] Failed to broadcast request badge update: #{e.class}: #{e.message}")
  end
end
