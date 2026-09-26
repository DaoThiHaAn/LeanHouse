class TenantPortal::ServiceUsageLogsController < TenantPortal::BaseController
  before_action :set_room
  before_action :set_stay_dates
  before_action :set_service_usage_log, only: %i[show edit update]

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

    @billing_month = parse_billing_month(params[:month])

    if @current_tab == "fixed"
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

      if @stay_start_month.nil? || @billing_month >= @stay_start_month
        scope = scope.where(billing_month: @billing_month)
      else
        scope = scope.none
      end

      @logs = scope
    end
  end

  # Returns the single row partial when requested inside Turbo Frame, or redirects to index
  def show
    respond_to do |format|
      format.html do
        if turbo_frame_request?
          render partial: "tenant_portal/service_usage_logs/row", locals: { log: @log }
        else
          redirect_to tenant_service_usage_logs_path(month: @log.billing_month.strftime("%Y-%m"))
        end
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(helpers.dom_id(@log), partial: "tenant_portal/service_usage_logs/row", locals: { log: @log })
      end
    end
  end

  # Editing is locked if the log has already been confirmed or billed
  def edit
    unless @log.can_be_edited_by_tenant?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = t("errors.landlord_confirm")
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@log), partial: "tenant_portal/service_usage_logs/row", locals: { log: @log }),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
          ]
        end
        format.html { redirect_to tenant_service_usage_logs_path, alert: t("errors.landlord_confirm") }
      end
    end
  end

  # Tenant submits reading and photo for an incomplete log created by the landlord
  def update
    unless @log.can_be_edited_by_tenant?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = t("errors.landlord_confirm")
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@log), partial: "tenant_portal/service_usage_logs/row", locals: { log: @log }),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
          ]
        end
        format.html { redirect_to tenant_service_usage_logs_path, alert: t("errors.landlord_confirm") }
      end
      return
    end

    if params.dig(:service_usage_log, :purge_reading_photo) == "1" && params.dig(:service_usage_log, :reading_photo).blank?
      @log.reading_photo.purge if @log.reading_photo.attached?
    end

    # Photo is required if not previously attached
    if !@log.reading_photo.attached? && params.dig(:service_usage_log, :reading_photo).blank?
      @log.errors.add(:reading_photo, t("invoice.reading_photo_required", default: "vui lòng chụp hoặc đính kèm ảnh công tơ thực tế"))
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity, formats: [ :html ] }
        format.html { render :edit, status: :unprocessable_entity }
      end
      return
    end

    @log.submitted_by = current_user
    if @log.update(tenant_log_params)
      notice_msg = t("invoice.submit_reading_success", default: "Đã gửi chỉ số và ảnh chụp công tơ thành công! Đang chờ chủ trọ duyệt.")
      flash[:notice] = notice_msg
      respond_to do |format|
        format.html do
          redirect_to tenant_service_usage_logs_path(month: @log.billing_month.strftime("%Y-%m")), notice: notice_msg
        end
        format.turbo_stream do
          if request.headers["Turbo-Frame"] == "_top"
            redirect_to tenant_service_usage_logs_path(month: @log.billing_month.strftime("%Y-%m")), notice: notice_msg
          else
            flash.now[:notice] = notice_msg
            render :update
          end
        end
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity, formats: [ :html ] }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_room
    @room = @tenant_stay.rental_unit.room
  end

  def set_stay_dates
    contract = @tenant_stay.contract
    start_date = [ @tenant_stay.checkin_at.to_date, contract ? contract.start_date : nil ].compact.min
    @stay_start_month = start_date.beginning_of_month
    @min_billing_month = @stay_start_month.strftime("%Y-%m")
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
    return Date.current.beginning_of_month if str.blank?

    str_val = str.to_s.strip
    if (m = str_val.match(/\A(\d{4})[-.\/](\d{1,2})\z/))
      year = m[1].to_i
      month = m[2].to_i
      return Date.new(year, month, 1) if month.between?(1, 12) && year.between?(2000, 2100)
    end

    begin
      Date.parse("#{str_val}-01").beginning_of_month
    rescue StandardError
      Date.current.beginning_of_month
    end
  end
end
