class LandlordPortal::MaintenanceLogsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :asset, through: :house
  load_and_authorize_resource :maintenance_log, through: :asset, except: %i[index filtered new create]

  LOGS_PER_PAGE = 15

  def index
    @has_logs = @asset.maintenance_logs.exists?
    @available_years = available_years
  end

  def filtered
    result = LandlordMaintenanceLogFilter.call(asset: @asset, params: params)
    @logs = result[:logs]
    @total_cost = result[:total_cost]
    @total_count = result[:total_count]

    render partial: "log_table", locals: {
      house: @house,
      asset: @asset,
      logs: @logs,
      total_cost: @total_cost,
      total_count: @total_count
    }
  end

  def new
    @log = @asset.maintenance_logs.build(performed_on: Date.current, cost: 0)
  end

  def edit
    @log = @maintenance_log
  end

  def create
    @log = @asset.maintenance_logs.build(log_params)

    if @log.save
      redirect_to landlord_house_asset_maintenance_logs_path(@house, @asset),
                  notice: t("success_messages.maintenance_log_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @log = @maintenance_log
    if @log.update(log_params)
      result = LandlordMaintenanceLogFilter.call(asset: @asset, params: params)
      @total_cost = result[:total_cost]

      flash.now[:notice] = t("success_messages.maintenance_log_updated")
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to landlord_house_asset_maintenance_logs_path(@house, @asset), notice: t("success_messages.maintenance_log_updated") }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @log = @maintenance_log
    @log.destroy
    result = LandlordMaintenanceLogFilter.call(asset: @asset, params: params)
    @total_cost = result[:total_cost]

    flash.now[:notice] = t("success_messages.maintenance_log_deleted")
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to landlord_house_asset_maintenance_logs_path(@house, @asset), notice: t("success_messages.maintenance_log_deleted") }
    end
  end

  private

  def log_params
    params.require(:maintenance_log).permit(:performed_on, :cost, :content)
  end

  def available_years
    current_year = Date.current.year
    earliest_year = @asset.maintenance_logs.minimum(:performed_on)&.year
    min_year = [ earliest_year || (current_year - 5), current_year - 5 ].min
    (min_year..current_year).to_a.reverse
  end
end
