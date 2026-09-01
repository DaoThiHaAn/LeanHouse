class LandlordPortal::ServiceUsageLogsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_billing_month, only: %i[index filtered confirm_all]
  before_action :set_service_usage_log, only: %i[edit update confirm destroy]

  def index
    load_logs
  end

  def filtered
    load_logs
    render partial: "logs_table", locals: { house: @house, logs: @logs, billing_month: @billing_month }
  end

  def new
    @room = @house.rooms.find_by(id: params[:room_id]) || @house.rooms.active.first
    @billing_month = (params[:billing_month]&.to_date || Date.current).beginning_of_month
    @service_variant = @house.service_variants.where(is_real_time: true).find_by(id: params[:service_variant_id]) || @house.service_variants.where(is_real_time: true).first

    prev_reading = @room ? previous_reading_for(@room, @service_variant&.service_id, @billing_month) : 0

    @log = ServiceUsageLog.new(
      room: @room,
      service_variant: @service_variant,
      service: @service_variant&.service,
      service_name: @service_variant&.service&.name || "Điện/Nước",
      unit: @service_variant&.human_unit || "kWh",
      unit_price: @service_variant&.fee || 0,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      prev_reading: prev_reading
    )
  end

  def create
    @log = ServiceUsageLog.new(log_params)
    @log.submitted_by = current_user
    @log.confirmed_by = current_user
    @log.confirmed_at = Time.current if @log.is_confirmed?

    if @log.save
      redirect_to landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")), notice: "Đã ghi nhận chỉ số dịch vụ thành công!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @log.update(log_params)
      redirect_to landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")), notice: "Đã cập nhật chỉ số thành công!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def confirm
    @log.update!(
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by: current_user
    )

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Đã xác nhận chỉ số phòng #{@log.room.name}!"
        load_logs
        render turbo_stream: [
          turbo_stream.replace("logs_table", partial: "logs_table", locals: { house: @house, logs: @logs, billing_month: @log.billing_month }),
          turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
        ]
      end
      format.html { redirect_to landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")), notice: "Đã xác nhận chỉ số!" }
    end
  end

  def confirm_all
    logs_to_confirm = @house.service_usage_logs.for_month(@billing_month).unconfirmed
    count = logs_to_confirm.count
    logs_to_confirm.update_all(
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by_id: current_user.id
    )

    redirect_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m")), notice: "Đã xác nhận toàn bộ #{count} chỉ số trong tháng!"
  end

  def destroy
    if @log.billed?
      redirect_to landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")), alert: "Chỉ số này đã được xuất hóa đơn, không thể xóa!"
    else
      @log.destroy
      redirect_to landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")), notice: "Đã xóa chỉ số thành công!"
    end
  end

  private

  def set_billing_month
    @billing_month = parse_month(params[:month])
  end

  def parse_month(str)
    return Date.current.beginning_of_month if str.blank?

    str_val = str.to_s.strip
    if str_val.match?(/\A\d{4}-\d{2}\z/)
      Date.parse("#{str_val}-01").beginning_of_month
    else
      Date.parse(str_val).beginning_of_month
    end
  rescue StandardError
    Date.current.beginning_of_month
  end

  def load_logs
    @logs = @house.service_usage_logs
                  .for_month(@billing_month)
                  .includes(:room, :service, :service_variant, :submitted_by, reading_photo_attachment: :blob)
                  .sorted

    if params[:status] == "confirmed"
      @logs = @logs.confirmed
    elsif params[:status] == "unconfirmed"
      @logs = @logs.unconfirmed
    end

    if params[:room_id].present?
      @logs = @logs.where(room_id: params[:room_id])
    end
  end

  def set_service_usage_log
    @log = @house.service_usage_logs.find(params[:id])
  end

  def previous_reading_for(room, service_id, month)
    room.service_usage_logs
        .where(service_id: service_id)
        .where("billing_month < ?", month)
        .order(billing_month: :desc)
        .pick(:latest_reading) || 0
  end

  def log_params
    params.require(:service_usage_log).permit(
      :room_id, :service_id, :service_variant_id, :service_name, :unit, :unit_price,
      :billing_month, :start_date, :end_date, :prev_reading, :latest_reading,
      :is_confirmed, :reading_photo
    )
  end
end
