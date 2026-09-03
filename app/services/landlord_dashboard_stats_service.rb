class LandlordDashboardStatsService
  def self.call(...)
    new(...).call
  end

  def initialize(landlord:, house_id: nil, target_date: Date.current)
    @landlord = landlord
    @house_id = house_id.presence && house_id != "all" ? house_id.to_i : nil
    @target_date = target_date
    @month_start = target_date.beginning_of_month.beginning_of_day
    @month_end = target_date.end_of_month.end_of_day
  end

  def call
    pending_reqs = calculate_pending_requests

    {
      house: selected_house,
      tenants_flow: calculate_tenant_flow,
      occupancy: calculate_occupancy,
      pending_requests: pending_reqs,
      pending_requests_count: pending_reqs[:total],
      contracts: calculate_contract_stats,
      invoices: calculate_invoice_stats
    }
  end

  private

  attr_reader :landlord, :house_id, :target_date, :month_start, :month_end

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

  # 1. New & Leaved unique tenant accounts in current month
  def calculate_tenant_flow
    house_ids = target_houses.select(:id)
    return { new_tenants: 0, leaved_tenants: 0 } if house_ids.empty?

    base_scope = TenantStay.joins(
      "INNER JOIN rental_units ON rental_units.id = tenant_stays.rental_unit_id
       LEFT JOIN rooms r_direct ON rental_units.rentable_type = 'Room' AND r_direct.id = rental_units.rentable_id
       LEFT JOIN beds b ON rental_units.rentable_type = 'Bed' AND b.id = rental_units.rentable_id
       LEFT JOIN rooms r_bed ON b.room_id = r_bed.id
       INNER JOIN floors ON floors.id = COALESCE(r_direct.floor_id, r_bed.floor_id)"
    ).where(floors: { house_id: house_ids })

    # Unique new tenants: checked in this month and was not already staying before month_start
    existing_tenant_ids = base_scope.where("tenant_stays.checkin_at < ?", month_start)
                                     .where("tenant_stays.checkout_at IS NULL OR tenant_stays.checkout_at >= ?", month_start)
                                     .select(:tenant_id)

    new_tenants_count = base_scope.where(tenant_stays: { checkin_at: month_start..month_end })
                                  .where.not(tenant_id: existing_tenant_ids)
                                  .select(:tenant_id)
                                  .distinct
                                  .count

    # Unique leaved tenants: checked out this month and does not have an active stay remaining in this house
    active_tenant_ids = base_scope.where(tenant_stays: { checkout_at: nil })
                                  .select(:tenant_id)

    leaved_tenants_count = base_scope.where(tenant_stays: { checkout_at: month_start..month_end })
                                     .where.not(tenant_id: active_tenant_ids)
                                     .select(:tenant_id)
                                     .distinct
                                     .count

    {
      new_tenants: new_tenants_count,
      leaved_tenants: leaved_tenants_count
    }
  end

  # 2. Occupancy rate (Single SQL aggregation)
  def calculate_occupancy
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

  # 3. Pending requests count and soonest expiring vehicle request
  def calculate_pending_requests
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

  # 4. Overdue and nearly-due contracts (Single SQL aggregation)
  def calculate_contract_stats
    house_ids = target_houses.select(:id)
    return { overdue: 0, nearly_due: 0, total: 0 } if house_ids.empty?

    scope = Contract.where(house_id: house_ids, end_date: nil)

    today = Date.current
    nearly_due_end = today + Contract::NEARLY_DUE_DAYS.days

    result = scope.select(
      ActiveRecord::Base.sanitize_sql_array([
        "COUNT(*) FILTER (WHERE contracts.due_date < :today) AS overdue_count,
         COUNT(*) FILTER (WHERE contracts.due_date BETWEEN :today AND :nearly_due_end) AS nearly_due_count",
        { today: today, nearly_due_end: nearly_due_end }
      ])
    ).take

    overdue = result&.overdue_count.to_i
    nearly_due = result&.nearly_due_count.to_i

    {
      overdue: overdue,
      nearly_due: nearly_due,
      total: overdue + nearly_due
    }
  end

  # 5. Monthly invoices summary: count, pending, overdue, amounts, collection rate
  def calculate_invoice_stats
    house_ids = target_houses.select(:id)
    empty_res = { total: 0, pending: 0, paid: 0, overdue: 0, total_amount: 0, paid_amount: 0, pending_amount: 0, collection_rate: 0.0 }
    return empty_res if house_ids.empty?

    invoices_scope = Invoice.where(house_id: house_ids)
                            .for_month(target_date.beginning_of_month)
                            .where.not(status: :cancelled)

    today = Date.current

    stats = invoices_scope.select(
      ActiveRecord::Base.sanitize_sql_array([
        "COUNT(*) AS total_count,
         COUNT(*) FILTER (WHERE status = 'paid') AS paid_count,
         COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
         COUNT(*) FILTER (WHERE status = 'overdue' OR (status = 'pending' AND due_date < :today)) AS overdue_count,
         COALESCE(SUM(total_amount), 0) AS total_amount,
         COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0) AS paid_amount,
         COALESCE(SUM(total_amount) FILTER (WHERE status = 'pending' OR status = 'overdue'), 0) AS pending_amount",
        { today: today }
      ])
    ).take

    total_count = stats&.total_count.to_i
    paid_count = stats&.paid_count.to_i
    pending_count = stats&.pending_count.to_i
    overdue_count = stats&.overdue_count.to_i
    total_amount = stats&.total_amount.to_i
    paid_amount = stats&.paid_amount.to_i
    pending_amount = stats&.pending_amount.to_i

    collection_rate = total_amount.positive? ? ((paid_amount.to_f / total_amount) * 100).round(1) : 0.0

    {
      total: total_count,
      paid: paid_count,
      pending: pending_count,
      overdue: overdue_count,
      total_amount: total_amount,
      paid_amount: paid_amount,
      pending_amount: pending_amount,
      collection_rate: collection_rate
    }
  end
end
