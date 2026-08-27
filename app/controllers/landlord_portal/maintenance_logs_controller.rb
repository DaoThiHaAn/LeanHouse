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
    @logs = filtered_logs
    render partial: "log_table", locals: { house: @house, asset: @asset, logs: @logs }
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
      flash.now[:notice] = t("success_messages.maintenance_log_updated")
      render turbo_stream: [
        turbo_stream.replace(
          ActionView::RecordIdentifier.dom_id(@log),
          partial: "landlord_portal/maintenance_logs/log_row",
          locals: { house: @house, asset: @asset, log: @log }
        ),
        turbo_stream.append(
          "events",
          partial: "layouts/shared_components/event",
          locals: { event: "close-modal" }
        ),
        turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
      ]
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @log = @maintenance_log
    @log.destroy
    flash.now[:notice] = t("success_messages.maintenance_log_deleted")
    render turbo_stream: [
      turbo_stream.remove(ActionView::RecordIdentifier.dom_id(@log)),
      turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
    ]
  end

  private

  def log_params
    params.require(:maintenance_log).permit(:performed_on, :cost, :content)
  end

  def filtered_logs
    scope = @asset.maintenance_logs

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

    scope.order(performed_on: :desc, created_at: :desc)
         .page(params[:page])
         .per(LOGS_PER_PAGE)
  end

  def available_years
    current_year = Date.current.year
    earliest_year = @asset.maintenance_logs.minimum(:performed_on)&.year
    min_year = [ earliest_year || (current_year - 5), current_year - 5 ].min
    (min_year..current_year).to_a.reverse
  end
end
