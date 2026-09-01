class TenantPortal::ServiceUsageLogsController < TenantPortal::BaseController
  before_action :set_room
  before_action :set_service_usage_log, only: %i[edit update]

  def index
    @logs = @room.service_usage_logs
                 .includes(:service, :service_variant, reading_photo_attachment: :blob)
                 .sorted
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

  def set_service_usage_log
    @log = @room.service_usage_logs.find(params[:id])
  end

  def tenant_log_params
    params.require(:service_usage_log).permit(:latest_reading, :reading_photo)
  end
end
