# frozen_string_literal: true

class LandlordPortal::ServiceUsageLogsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_room, only: %i[index filtered confirm_all new]
  before_action :set_billing_month, only: %i[index filtered]
  before_action :set_service_usage_log, only: %i[edit update confirm destroy]

  def index
    if @room
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
      @unconfirmed_count = @room.service_usage_logs.unconfirmed.count
      @services = @house.services.name_sorted
      render :room_index
    else
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, params: params.reverse_merge(month: @billing_month.strftime("%Y-%m")))
      @unconfirmed_count = @house.service_usage_logs.for_month(@billing_month).unconfirmed.count
      @selected_service = @house.services.find_by(id: params[:service_id]) if params[:service_id].present?
      @services = @house.services.name_sorted
      @service_variants = @selected_service ? @selected_service.service_variants : @house.service_variants.where(is_real_time: true)
    end
  end

  def filtered
    if @room
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
      render partial: "room_logs_table", locals: { house: @house, room: @room, logs: @logs }
    else
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, params: params.reverse_merge(month: @billing_month.strftime("%Y-%m")))
      render partial: "logs_table", locals: { house: @house, logs: @logs, billing_month: @billing_month }
    end
  end

  def new
    target_room = @room || @house.rooms.find_by(id: params[:room_id]) || @house.rooms.active.first
    @billing_month = (params[:billing_month]&.to_date || Date.current).beginning_of_month
    service_variant = @house.service_variants.where(is_real_time: true).find_by(id: params[:service_variant_id]) ||
                      @house.service_variants.where(is_real_time: true).first

    prev_reading = target_room ? previous_reading_for(target_room, service_variant&.service_id, @billing_month) : 0

    @log = ServiceUsageLog.new(
      room: target_room,
      service_variant: service_variant,
      service: service_variant&.service,
      service_name: service_variant&.service&.name || "Điện/Nước",
      unit: service_variant&.human_unit || "kWh",
      unit_price: service_variant&.fee || 0,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      prev_reading: prev_reading
    )
  end

  def create
    @log = ServiceUsageLog.new(log_params)
    @log.submitted_by = current_user
    @log.confirmed_by = current_user if @log.is_confirmed?
    @log.confirmed_at = Time.current if @log.is_confirmed?
    @billing_month = @log.billing_month || Date.current.beginning_of_month

    if @log.save
      redirect_to determine_redirect_path(@log), notice: t("service_usage_logs.create_success", default: "Đã ghi nhận chỉ số dịch vụ thành công!")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @log.allow_landlord_override = true

    if @log.update(log_params)
      redirect_to determine_redirect_path(@log), notice: t("service_usage_logs.update_success", default: "Đã cập nhật chỉ số thành công!")
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
        flash.now[:notice] = t("service_usage_logs.confirm_log_success", room: @log.room.name, default: "Đã xác nhận chỉ số phòng #{@log.room.name}!")
        if from_room_context?
          @room = @log.room
          @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
          render turbo_stream: [
            turbo_stream.replace("room_logs_table", partial: "room_logs_table", locals: { house: @house, room: @room, logs: @logs }),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
          ]
        else
          @billing_month = @log.billing_month
          @logs = LandlordServiceUsageLogsFilter.call(house: @house, params: params.reverse_merge(month: @billing_month.strftime("%Y-%m")))
          render turbo_stream: [
            turbo_stream.replace("logs_table", partial: "logs_table", locals: { house: @house, logs: @logs, billing_month: @billing_month }),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
          ]
        end
      end
      format.html do
        redirect_back fallback_location: landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")),
                      notice: t("service_usage_logs.confirm_log_success", room: @log.room.name, default: "Đã xác nhận chỉ số!")
      end
    end
  end

  def confirm_all
    if @room
      logs_to_confirm = @room.service_usage_logs.unconfirmed
      count = logs_to_confirm.count
      logs_to_confirm.update_all(
        is_confirmed: true,
        confirmed_at: Time.current,
        confirmed_by_id: current_user.id
      )
      redirect_to landlord_house_room_service_usage_logs_path(@house, @room),
                  notice: t("service_usage_logs.confirm_all_room_success", count: count, room: @room.name, default: "Đã xác nhận #{count} chỉ số của phòng #{@room.name}!")
    else
      @billing_month = parse_month(params[:month])
      logs_to_confirm = @house.service_usage_logs.for_month(@billing_month).unconfirmed
      count = logs_to_confirm.count
      logs_to_confirm.update_all(
        is_confirmed: true,
        confirmed_at: Time.current,
        confirmed_by_id: current_user.id
      )
      redirect_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m")),
                  notice: t("service_usage_logs.confirm_all_success", count: count, default: "Đã xác nhận toàn bộ #{count} chỉ số trong tháng!")
    end
  end

  def destroy
    if @log.billed?
      redirect_back fallback_location: landlord_house_service_usage_logs_path(@house),
                    alert: t("service_usage_logs.cannot_delete_billed", default: "Chỉ số này đã được xuất hóa đơn, không thể xóa!")
    else
      redirect_path = determine_redirect_path(@log)
      @log.destroy
      redirect_to redirect_path, notice: t("service_usage_logs.delete_success", default: "Đã xóa chỉ số thành công!")
    end
  end

  private

  def set_room
    @room = @house.rooms.find_by(id: params[:room_id]) if params[:room_id].present?
  end

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

  def from_room_context?
    params[:from_room] == "true" || params[:room_id].present? || request.referer&.include?("/rooms/#{@log.room_id}/")
  end

  def determine_redirect_path(log)
    if from_room_context?
      landlord_house_room_service_usage_logs_path(@house, log.room)
    else
      landlord_house_service_usage_logs_path(@house, month: log.billing_month.strftime("%Y-%m"))
    end
  end

  def log_params
    params.require(:service_usage_log).permit(
      :room_id, :service_id, :service_variant_id, :service_name, :unit, :unit_price,
      :billing_month, :start_date, :end_date, :prev_reading, :latest_reading,
      :is_confirmed, :reading_photo
    )
  end
end
