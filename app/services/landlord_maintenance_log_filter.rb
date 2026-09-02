class LandlordMaintenanceLogFilter
  LOGS_PER_PAGE = 15

  def self.call(...)
    new(...).call
  end

  def initialize(asset:, params:)
    @asset = asset
    @params = params
  end

  def call
    scope = filter_scope
    total_cost = scope.sum(:cost)
    total_count = scope.count

    paginated_logs = scope.order(performed_on: :desc, created_at: :desc)
                          .page(params[:page])
                          .per(LOGS_PER_PAGE)

    {
      logs: paginated_logs,
      total_cost: total_cost,
      total_count: total_count
    }
  end

  private

  attr_reader :asset, :params

  def filter_scope
    scope = asset.maintenance_logs

    if params[:year].present?
      year = params[:year].to_i
      if params[:month].present?
        month = params[:month].to_i
        start_date = Date.new(year, month, 1)
        end_date = start_date.end_of_month
        scope = scope.where(performed_on: start_date..end_date)
      else
        start_date = Date.new(year, 1, 1)
        end_date = Date.new(year, 12, 31)
        scope = scope.where(performed_on: start_date..end_date)
      end
    elsif params[:month].present?
      month = params[:month].to_i
      scope = scope.where("EXTRACT(MONTH FROM performed_on) = ?", month)
    end

    scope
  end
end
