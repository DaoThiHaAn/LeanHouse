class LandlordPortal::DashboardsController < LandlordPortal::BaseController
  def show
    @houses = @landlord.houses.active.sorted
    @selected_house_id = params[:house_id].presence
    @target_date, @has_month_param = parse_month(params[:month])
    @is_current_month = (@target_date.year == Date.current.year && @target_date.month == Date.current.month)
    @view_mode = @has_month_param ? :detailed : :overall

    @stats = LandlordDashboardStatsService.call(
      landlord: @landlord,
      house_id: @selected_house_id,
      target_date: @target_date
    )
    @selected_house = @stats[:house]
  end

  private

  def parse_month(month_param)
    if month_param.present?
      [ Date.strptime(month_param.to_s, "%Y-%m").beginning_of_month, true ]
    else
      [ Date.current.beginning_of_month, false ]
    end
  rescue ArgumentError, Date::Error
    [ Date.current.beginning_of_month, false ]
  end
end
