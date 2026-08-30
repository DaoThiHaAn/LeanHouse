class TenantPortal::DashboardController < TenantPortal::BaseController
  def show
    @stats = TenantDashboardStatsService.call(
      tenant: @tenant,
      tenant_stay: @tenant_stay
    )
  end
end
