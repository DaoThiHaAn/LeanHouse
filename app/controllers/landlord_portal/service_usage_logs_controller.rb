# frozen_string_literal: true

class LandlordPortal::ServiceUsageLogsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_room, only: %i[index filtered confirm_all new]
  before_action :set_billing_month, only: %i[index filtered]
  before_action :set_service_usage_log, only: %i[show edit update confirm destroy]
  before_action :load_floor_and_room_options, only: %i[new create]

  def index
    if @room
      setup_room_index
      render :room_index
    else
      setup_house_index
    end
  end

  def filtered
    if @room
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
      render partial: "room_logs_table", locals: { house: @house, room: @room, logs: @logs }
    elsif params[:tab] == "fixed"
      @fixed_services_summary = HouseFixedServicesSummary.call(
        house: @house,
        billing_month: @billing_month,
        params: params
      )
      render partial: "house_fixed_services_table", locals: { house: @house, summary: @fixed_services_summary }
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

    prev_reading = target_room ? ServiceUsageLog.previous_reading_for(room: target_room, service_id: service_variant&.service_id, before_month: @billing_month) : 0

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

  # Creates a service usage log:
  # - If is_confirmed: true -> landlord confirms & finalizes reading now
  # - If is_confirmed: false -> opens the cycle and awaits tenant photo/reading submission
  def create
    @log = ServiceUsageLog.new(log_params)
    @log.submitted_by = current_user

    if @log.is_confirmed?
      @log.confirmed_by = current_user
      @log.confirmed_at = Time.current
    else
      @log.confirmed_by = nil
      @log.confirmed_at = nil
    end
    @billing_month = @log.billing_month || Date.current.beginning_of_month

    if @log.save
      redirect_to determine_redirect_path(@log), notice: t("service_usage_logs.create_success", default: "Đã ghi nhận chỉ số dịch vụ thành công!")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
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

  # Confirms a single log, locks tenant editing, and notifies active staying tenants
  def confirm
    @log.update!(
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by: current_user
    )
    notify_tenants_of_confirmed_log(@log)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("service_usage_logs.confirm_log_success", room: @log.room.name, default: "Đã xác nhận chỉ số phòng #{@log.room.name}!")
        if from_room_context?
          @room = @log.room
          @unconfirmed_count = @room.service_usage_logs.unconfirmed.count
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@log), partial: "room_log_row", locals: { house: @house, room: @room, log: @log }),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message"),
            turbo_stream.replace("room_unconfirmed_badge", partial: "unconfirmed_badge", locals: { id: "room_unconfirmed_badge", count: @unconfirmed_count }),
            turbo_stream.replace("room_confirm_all_btn", partial: "room_confirm_all_btn", locals: { house: @house, room: @room, count: @unconfirmed_count })
          ]
        else
          @billing_month = @log.billing_month
          @unconfirmed_count = @house.service_usage_logs.for_month(@billing_month).unconfirmed.count
          @selected_service = @house.services.find_by(id: params[:service_id]) if params[:service_id].present?
          render turbo_stream: [
            turbo_stream.replace(helpers.dom_id(@log), partial: "log_row", locals: { house: @house, log: @log }),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message"),
            turbo_stream.replace("house_unconfirmed_badge", partial: "unconfirmed_badge", locals: { id: "house_unconfirmed_badge", count: @unconfirmed_count }),
            turbo_stream.replace("house_confirm_all_btn", partial: "house_confirm_all_btn", locals: { house: @house, billing_month: @billing_month, selected_service: @selected_service, count: @unconfirmed_count })
          ]
        end
      end
      format.html do
        redirect_back fallback_location: landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")),
                      notice: t("service_usage_logs.confirm_log_success", room: @log.room.name, default: "Đã xác nhận chỉ số!")
      end
    end
  end

  # Batch confirms unconfirmed logs (either for a specific room or for the entire house/month)
  # and notifies staying tenants of the confirmed records
  def confirm_all
    if @room
      logs_to_confirm = @room.service_usage_logs.unconfirmed.to_a
      count = logs_to_confirm.count
      @room.service_usage_logs.unconfirmed.update_all(
        is_confirmed: true,
        confirmed_at: Time.current,
        confirmed_by_id: current_user.id
      )
      notify_tenants_of_confirmed_logs(logs_to_confirm)
      redirect_to landlord_house_room_service_usage_logs_path(@house, @room),
                  notice: t("service_usage_logs.confirm_all_room_success", count: count, room: @room.name, default: "Đã xác nhận #{count} chỉ số của phòng #{@room.name}!")
    else
      @billing_month = parse_month(params[:month])
      logs_to_confirm = @house.service_usage_logs.for_month(@billing_month).unconfirmed.to_a
      count = logs_to_confirm.count
      @house.service_usage_logs.for_month(@billing_month).unconfirmed.update_all(
        is_confirmed: true,
        confirmed_at: Time.current,
        confirmed_by_id: current_user.id
      )
      notify_tenants_of_confirmed_logs(logs_to_confirm)
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
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = t("service_usage_logs.delete_success", default: "Đã xóa chỉ số thành công!")
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
        format.html { redirect_to redirect_path, notice: t("service_usage_logs.delete_success", default: "Đã xóa chỉ số thành công!") }
      end
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

  def set_service_usage_log
    @log = @house.service_usage_logs.find(params[:id])
  end

  def notify_tenants_of_confirmed_log(log)
    tenants = log.room.active_staying_tenant_users
    return if tenants.empty?

    ServiceUsageLogConfirmedNotifier.with(log: log).deliver_later(tenants)
  end

  def notify_tenants_of_confirmed_logs(logs)
    logs.each { |log| notify_tenants_of_confirmed_log(log) }
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

  def setup_room_index
    @unconfirmed_count = @room.service_usage_logs.unconfirmed.count
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
      @fixed_services_summary = RoomFixedServicesSummary.call(
        room: @room,
        billing_month: @billing_month,
        page: params[:page],
        per_page: params[:per_page]
      )
    else
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
      @services = @house.services.name_sorted
    end
  end

  def setup_house_index
    @unconfirmed_count = @house.service_usage_logs.for_month(@billing_month).unconfirmed.count
    @fixed_services_count = RoomService.where(room_id: @house.rooms.select(:id)).joins(:service_variant).where(service_variants: { is_real_time: false }).count
    @selected_service = @house.services.find_by(id: params[:service_id]) if params[:service_id].present?

    @current_tab = if params[:tab].present?
      params[:tab] == "fixed" ? "fixed" : "real_time"
    elsif @selected_service.present?
      @selected_service.service_variants.any?(&:is_real_time?) ? "real_time" : "fixed"
    else
      "real_time"
    end

    if @current_tab == "fixed"
      @fixed_services_summary = HouseFixedServicesSummary.call(
        house: @house,
        billing_month: @billing_month,
        params: params
      )
      @fixed_services = @house.services.joins(:service_variants).where(service_variants: { is_real_time: false }).distinct.name_sorted
      @fixed_variants = if @selected_service
        @selected_service.service_variants.where(is_real_time: false)
      else
        @house.service_variants.where(is_real_time: false)
      end
    else
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, params: params.reverse_merge(month: @billing_month.strftime("%Y-%m")))
      @services = @house.services.joins(:service_variants).where(service_variants: { is_real_time: true }).distinct.name_sorted
      @service_variants = @selected_service ? @selected_service.service_variants.where(is_real_time: true) : @house.service_variants.where(is_real_time: true)
    end
  end

  # Loads floor and room options for the dependent floor & room input group picker
  def load_floor_and_room_options
    @rooms = @house.rooms.active.includes(:floor).sorted
    @floors = @rooms.map(&:floor).compact.uniq.sort_by(&:position)
    @room_options = @rooms.map do |r|
      {
        id: r.id,
        floorId: r.floor_id,
        name: r.title_name
      }
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
