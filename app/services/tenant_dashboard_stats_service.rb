class TenantDashboardStatsService
  def self.call(...)
    new(...).call
  end

  def initialize(tenant:, tenant_stay: nil)
    @tenant = tenant
    @tenant_stay = tenant_stay
  end

  def call
    contract = resolve_contract
    stay_stats = calculate_stay_stats(contract)
    pending_stats = calculate_pending_requests_stats

    {
      contract: contract,
      days_stayed: stay_stats[:days_stayed],
      total_days: stay_stats[:total_days],
      stay_progress_pct: stay_stats[:stay_progress_pct],
      pending_requests_count: pending_stats[:count],
      soonest_vehicle_request: pending_stats[:soonest_vehicle_request],
      invoices: calculate_invoice_stats
    }
  end

  private

  attr_reader :tenant, :tenant_stay

  def resolve_contract
    tenant_stay&.contract || tenant.latest_contract
  end

  def calculate_stay_stats(contract)
    if contract&.start_date && contract&.due_date
      days_stayed = [ (Date.current - contract.start_date).to_i, 0 ].max
      total_days = [ (contract.due_date - contract.start_date).to_i, 1 ].max
      stay_progress_pct = [ ((days_stayed.to_f / total_days) * 100).round, 100 ].min

      {
        days_stayed: days_stayed,
        total_days: total_days,
        stay_progress_pct: stay_progress_pct
      }
    else
      {
        days_stayed: 0,
        total_days: 0,
        stay_progress_pct: 0
      }
    end
  end

  def calculate_pending_requests_stats
    pending_scope = tenant.requests.pending
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
      count: total,
      soonest_vehicle_request: soonest_info
    }
  end

  def calculate_invoice_stats
    house = tenant_stay&.rental_unit&.house
    room = tenant_stay&.rental_unit&.room
    return empty_invoice_stats unless house && room

    scope = house.invoices
                 .where("invoices.room_id = :room_id OR invoices.tenant_id = :tenant_id", room_id: room.id, tenant_id: tenant.id)
                 .kept
                 .where.not(status: :cancelled)

    today = Date.current

    stats = scope.select(
      ActiveRecord::Base.sanitize_sql_array([
        "COUNT(*) AS total_count,
         COUNT(*) FILTER (WHERE status = 'pending' OR status = 'overdue') AS unpaid_count,
         COUNT(*) FILTER (WHERE status = 'overdue' OR (status = 'pending' AND due_date < :today)) AS overdue_count,
         COALESCE(SUM(total_amount) FILTER (WHERE status = 'pending' OR status = 'overdue'), 0) AS unpaid_amount,
         COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0) AS paid_amount",
        { today: today }
      ])
    ).take

    unpaid_count = stats&.unpaid_count.to_i
    overdue_count = stats&.overdue_count.to_i
    unpaid_amount = stats&.unpaid_amount.to_i
    paid_amount = stats&.paid_amount.to_i
    total_count = stats&.total_count.to_i

    upcoming_unpaid = scope.where(status: :pending).where("due_date >= ?", today).order(due_date: :asc)
    nearest_due_date = upcoming_unpaid.first&.due_date

    {
      total_count: total_count,
      unpaid_count: unpaid_count,
      overdue_count: overdue_count,
      unpaid_amount: unpaid_amount,
      paid_amount: paid_amount,
      nearest_due_date: nearest_due_date,
      has_invoices: total_count.positive?
    }
  end

  def empty_invoice_stats
    {
      total_count: 0,
      unpaid_count: 0,
      overdue_count: 0,
      unpaid_amount: 0,
      paid_amount: 0,
      nearest_due_date: nil,
      has_invoices: false
    }
  end
end
