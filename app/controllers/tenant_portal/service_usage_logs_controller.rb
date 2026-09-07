class TenantPortal::ServiceUsageLogsController < TenantPortal::BaseController
  before_action :set_room
  before_action :set_stay_dates
  before_action :set_service_usage_log, only: %i[edit update]

  def index
    @unconfirmed_count = tenant_visible_logs.unconfirmed.count
    @fixed_services_count = @room.room_services.joins(:service_variant).where(service_variants: { is_real_time: false }).count

    @current_tab = if params[:tab].present?
      params[:tab] == "fixed" ? "fixed" : "real_time"
    elsif @room.service_variants.any?(&:is_real_time?)
      "real_time"
    elsif @fixed_services_count.positive?
      "fixed"
    else
      "real_time"
    end

    if @current_tab == "fixed"
      @billing_month = parse_billing_month(params[:month])
      @fixed_services_summary = RoomFixedServicesSummary.call(
        room: @room,
        billing_month: @billing_month,
        page: params[:page],
        per_page: params[:per_page],
        tenant: @tenant
      )
    else
      scope = tenant_visible_logs
                   .includes(:service, :service_variant, reading_photo_attachment: :blob)
                   .sorted

      if params[:month].present? && params[:month].to_s.match?(/\A\d{4}-\d{2}\z/)
        begin
          filter_month = Date.parse("#{params[:month]}-01").beginning_of_month
          if @stay_start_month.nil? || filter_month >= @stay_start_month
            scope = scope.where(billing_month: filter_month)
          else
            scope = scope.none
          end
        rescue ArgumentError
          # Ignore invalid date
        end
      end

      @logs = scope
    end
  end

  def edit
    unless @log.can_be_edited_by_tenant?
      redirect_to tenant_service_usage_logs_path, alert: "Chỉ số này đã được chủ trọ xác nhận, không thể chỉnh sửa."
    end
  end

  def update
    unless @log.can_be_edited_by_tenant?
      redirect_to tenant_service_usage_logs_path, alert: "Chỉ số này đã được chủ trọ xác nhận, không thể chỉnh sửa."
      return
    end

    @log.submitted_by = current_user
    if @log.update(tenant_log_params)
      redirect_to tenant_service_usage_logs_path, notice: "Đã gửi chỉ số và ảnh chụp công tơ thành công! Đang chờ chủ trọ duyệt."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_room
    @room = @tenant_stay.rental_unit.room
  end

  def set_stay_dates
    start_date = [ @tenant_stay&.checkin_at&.to_date, @tenant_stay&.contract&.start_date ].compact.min
    @stay_start_month = start_date&.beginning_of_month
    @min_billing_month = @stay_start_month&.strftime("%Y-%m")
  end

  def tenant_visible_logs
    scope = @room.service_usage_logs
    if @stay_start_month.present?
      scope.where("service_usage_logs.billing_month >= ?", @stay_start_month)
    else
      scope
    end
  end

  def set_service_usage_log
    @log = tenant_visible_logs.find(params[:id])
  end

  def tenant_log_params
    params.require(:service_usage_log).permit(:latest_reading, :reading_photo)
  end

  def parse_billing_month(str)
    month = if str.present? && str.to_s.match?(/\A\d{4}-\d{2}\z/)
      begin
        Date.parse("#{str}-01").beginning_of_month
      rescue ArgumentError
        Date.current.beginning_of_month
      end
    else
      Date.current.beginning_of_month
    end

    if @stay_start_month.present? && month < @stay_start_month
      @stay_start_month
    else
      month
    end
  end
end
