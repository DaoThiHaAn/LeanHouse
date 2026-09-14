module LandlordDashboard
  class RequestStatsCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(target_houses)
      @target_houses = target_houses
    end

    def call
      house_ids = target_houses.select(:id)
      return { total: 0, soonest_vehicle_request: nil } if house_ids.empty?

      pending_scope = Request.where(house_id: house_ids, status: :pending)
      total = pending_scope.count

      soonest_vr = pending_scope.where(requestable_type: "VehicleRequest")
                                .where("created_at > ?", Request::EXPIRED_DAYS.days.ago)
                                .order(created_at: :asc)
                                .first

      soonest_info = if soonest_vr
        expiry_time = soonest_vr.created_at + Request::EXPIRED_DAYS.days
        remaining_seconds = [ (expiry_time - Time.current).to_i, 0 ].max
        remaining_days = remaining_seconds / 1.day
        remaining_hours = (remaining_seconds % 1.day) / 1.hour

        {
          id: soonest_vr.id,
          expiry_time: expiry_time,
          remaining_days: remaining_days,
          remaining_hours: remaining_hours,
          is_urgent: remaining_seconds <= 2.days.to_i
        }
      end

      {
        total: total,
        soonest_vehicle_request: soonest_info
      }
    end

    private

    attr_reader :target_houses
  end
end
