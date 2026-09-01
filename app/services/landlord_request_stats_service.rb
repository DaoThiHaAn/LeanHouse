class LandlordRequestStatsService
  NEARLY_DUE_WINDOW_DAYS = 2

  def self.call(...)
    new(...).call
  end

  def initialize(landlord:)
    @landlord = landlord
  end

  def call
    requests_scope = landlord.requests
    pending_scope = requests_scope.where(status: :pending)

    pending_count = pending_scope.count
    handling_count = requests_scope.where(status: :handling).count

    # Actionable pending vehicle requests (created within EXPIRED_DAYS = 7 days)
    pending_vr_scope = pending_scope.where(requestable_type: "VehicleRequest")
                                    .where("requests.created_at > ?", Request::EXPIRED_DAYS.days.ago)

    # 1. Due today: expires by end of today
    # (i.e. created_at + 7.days <= Time.current.end_of_day)
    due_today_count = pending_vr_scope.where(
      "requests.created_at <= ?",
      Time.current.end_of_day - Request::EXPIRED_DAYS.days
    ).count

    # 2. Expiring after today (within NEARLY_DUE_WINDOW_DAYS = 2 days after today)
    # (i.e. Time.current.end_of_day < created_at + 7.days <= (Time.current + 2.days).end_of_day)
    expiring_after_today_count = pending_vr_scope.where(
      "requests.created_at > ? AND requests.created_at <= ?",
      Time.current.end_of_day - Request::EXPIRED_DAYS.days,
      (Time.current + NEARLY_DUE_WINDOW_DAYS.days).end_of_day - Request::EXPIRED_DAYS.days
    ).count

    expiring_total_count = due_today_count + expiring_after_today_count

    # 3. Resolved this month (approved, completed, rejected)
    month_start = Time.current.beginning_of_month
    month_end = Time.current.end_of_month
    resolved_this_month_count = requests_scope.where(status: %i[approved completed rejected])
                                              .where(resolved_at: month_start..month_end)
                                              .count

    {
      pending_count: pending_count,
      handling_count: handling_count,
      due_today_count: due_today_count,
      expiring_after_today_count: expiring_after_today_count,
      expiring_total_count: expiring_total_count,
      resolved_this_month_count: resolved_this_month_count
    }
  end

  private

  attr_reader :landlord
end
