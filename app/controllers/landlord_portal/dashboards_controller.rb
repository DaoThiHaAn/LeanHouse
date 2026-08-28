class LandlordPortal::DashboardsController < LandlordPortal::BaseController
  def show
    @houses = @landlord.houses.active.sorted
    @selected_house_id = params[:house_id].presence
    @stats = LandlordDashboardStatsService.call(
      landlord: @landlord,
      house_id: @selected_house_id
    )
    @selected_house = @stats[:house]

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
