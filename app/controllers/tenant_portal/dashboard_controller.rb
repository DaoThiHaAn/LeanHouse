class TenantPortal::DashboardController < TenantPortal::BaseController
  def show
    @contract = @tenant_stay&.contract || @tenant.latest_contract

    if @contract&.start_date && @contract&.due_date
      @days_stayed = [ (Date.current - @contract.start_date).to_i, 0 ].max
      @total_days = [ (@contract.due_date - @contract.start_date).to_i, 1 ].max
      @stay_progress_pct = [ ((@days_stayed.to_f / @total_days) * 100).round, 100 ].min
    else
      @days_stayed = 0
      @total_days = 0
      @stay_progress_pct = 0
    end

    pending_scope = @tenant.requests.pending
    @pending_requests_count = pending_scope.count

    soonest_vr = pending_scope.where(requestable_type: "VehicleRequest")
                              .where("created_at > ?", Request::EXPIRED_DAYS.days.ago)
                              .order(created_at: :asc)
                              .first

    @soonest_vehicle_request = if soonest_vr
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
  end
end
