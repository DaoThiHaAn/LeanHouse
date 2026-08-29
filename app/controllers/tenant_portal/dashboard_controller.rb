class TenantPortal::DashboardController < TenantPortal::BaseController
  def show
    @contract = @tenant_stay&.contract || @tenant.latest_contract

    if @contract&.start_date && @contract&.due_date
      @days_stayed = [(Date.current - @contract.start_date).to_i, 0].max
      @total_days = [(@contract.due_date - @contract.start_date).to_i, 1].max
      @stay_progress_pct = [((@days_stayed.to_f / @total_days) * 100).round, 100].min
    else
      @days_stayed = 0
      @total_days = 0
      @stay_progress_pct = 0
    end

    @pending_requests_count = @tenant.requests.pending.count
  end
end
