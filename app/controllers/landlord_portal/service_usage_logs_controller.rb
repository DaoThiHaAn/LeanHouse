# frozen_string_literal: true

class LandlordPortal::ServiceUsageLogsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_room, only: %i[room_index filtered_room confirm_all_room new]
  before_action :set_selected_service, only: %i[service_index filtered_service confirm_all_service]
  before_action :set_billing_month, only: %i[index filtered room_index filtered_room service_index filtered_service]
  before_action :set_service_usage_log, only: %i[show edit update confirm destroy]
  before_action :load_floor_and_room_options, only: %i[new create]

  def index
    if params[:service_id].present? && (@selected_service = @house.services.find_by(id: params[:service_id]))
      redirect_to landlord_house_service_service_usage_logs_path(@house, @selected_service, request.query_parameters.except("service_id"))
      return
    end

    assign_index_data(LandlordServiceUsageLogsIndexBuilder.for_house(house: @house, billing_month: @billing_month, params: params))
    render :index
  end

  def filtered
    if params[:tab] == "fixed"
      @fixed_services_summary = HouseFixedServicesSummary.call(house: @house, billing_month: @billing_month, params: params)
      render partial: "house_fixed_services_table", locals: { house: @house, summary: @fixed_services_summary }
    else
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, params: params.reverse_merge(month: @billing_month.strftime("%Y-%m")))
      render partial: "logs_table", locals: { house: @house, logs: @logs, billing_month: @billing_month }
    end
  end

  def room_index
    assign_index_data(LandlordServiceUsageLogsIndexBuilder.for_room(house: @house, room: @room, billing_month: @billing_month, params: params))
    render :room_index
  end

  def filtered_room
    if params[:tab] == "fixed"
      @fixed_services_summary = RoomFixedServicesSummary.call(
        room: @room,
        billing_month: @billing_month,
        page: params[:page],
        per_page: params[:per_page]
      )
      render partial: "room_fixed_services_table", locals: { house: @house, room: @room, summary: @fixed_services_summary }
    else
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
      render partial: "room_logs_table", locals: { house: @house, room: @room, logs: @logs }
    end
  end

  def service_index
    assign_index_data(LandlordServiceUsageLogsIndexBuilder.for_service(house: @house, service: @selected_service, billing_month: @billing_month, params: params))
    render :service_index
  end

  def filtered_service
    if params[:tab] == "fixed"
      @fixed_services_summary = HouseFixedServicesSummary.call(
        house: @house,
        billing_month: @billing_month,
        params: params.merge(service_id: @selected_service.id)
      )
      render partial: "house_fixed_services_table", locals: { house: @house, summary: @fixed_services_summary }
    else
      @logs = LandlordServiceUsageLogsFilter.call(
        house: @house,
        params: params.reverse_merge(month: @billing_month.strftime("%Y-%m"), service_id: @selected_service.id)
      )
      render partial: "logs_table", locals: { house: @house, logs: @logs, billing_month: @billing_month }
    end
  end

  def new
    @log = ServiceUsageLogCreator.build_default(house: @house, room: @room, params: params)
    @billing_month = @log.billing_month
  end

  # Creates a service usage log:
  # - If is_confirmed: true -> landlord confirms & finalizes reading now
  # - If is_confirmed: false -> opens the cycle and awaits tenant photo/reading submission
  def create
    @log = ServiceUsageLogCreator.call(log_params: log_params, user: current_user)
    @billing_month = @log.billing_month || Date.current.beginning_of_month

    if @log.persisted?
      redirect_to determine_redirect_path(@log), notice: t("service_usage_logs.create_success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    if @log.billed?
      redirect_to determine_redirect_path(@log), alert: t("service_usage_logs.cannot_edit_billed")
    end
  end

  def update
    if @log.billed?
      redirect_to determine_redirect_path(@log), alert: t("service_usage_logs.cannot_edit_billed")
      return
    end

    @log.allow_landlord_override = true

    attributes_to_update = log_params.to_h
    if log_params[:reading_photo].present?
      attributes_to_update[:submitted_by] = current_user
    end

    if log_params[:is_confirmed] == "1" || log_params[:is_confirmed] == true
      attributes_to_update[:confirmed_by] = current_user
      attributes_to_update[:confirmed_at] = Time.current
    end

    if @log.update(attributes_to_update)
      redirect_to determine_redirect_path(@log), notice: t("service_usage_logs.update_success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Confirms a single log, locks tenant editing, and notifies active staying tenants
  def confirm
    ServiceUsageLogConfirmer.confirm(log: @log, user: current_user)

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("service_usage_logs.confirm_log_success", room: @log.room.name)
        prepare_confirm_turbo_stream_state
      end

      format.html do
        redirect_back fallback_location: landlord_house_service_usage_logs_path(@house, month: @log.billing_month.strftime("%Y-%m")),
                      notice: t("service_usage_logs.confirm_log_success", room: @log.room.name)
      end
    end
  end

  def confirm_all_room
    count = ServiceUsageLogConfirmer.confirm_all(scope: @room.service_usage_logs, user: current_user)
    redirect_to landlord_house_room_service_usage_logs_path(@house, @room),
                notice: t("service_usage_logs.confirm_all_room_success", count: count, room: @room.name)
  end

  def confirm_all_service
    @billing_month = parse_month(params[:month])
    scope = @house.service_usage_logs.for_month(@billing_month).where(service_id: @selected_service.id)
    count = ServiceUsageLogConfirmer.confirm_all(scope: scope, user: current_user)
    redirect_to landlord_house_service_service_usage_logs_path(@house, @selected_service, month: @billing_month.strftime("%Y-%m")),
                notice: t("service_usage_logs.confirm_all_success", count: count)
  end

  # Batch confirms unconfirmed logs for the whole house / month
  # and notifies staying tenants of the confirmed records
  def confirm_all
    @billing_month = parse_month(params[:month])
    scope = @house.service_usage_logs.for_month(@billing_month)
    scope = scope.where(service_id: params[:service_id]) if params[:service_id].present?
    count = ServiceUsageLogConfirmer.confirm_all(scope: scope, user: current_user)

    redirect_path = if params[:service_id].present? && (@selected_service = @house.services.find_by(id: params[:service_id]))
      landlord_house_service_service_usage_logs_path(@house, @selected_service, month: @billing_month.strftime("%Y-%m"))
    else
      landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
    end
    redirect_to redirect_path,
                notice: t("service_usage_logs.confirm_all_success", count: count)
  end

  def destroy
    if @log.billed?
      redirect_back fallback_location: landlord_house_service_usage_logs_path(@house),
                    alert: t("service_usage_logs.cannot_delete_billed")
      return
    end

    redirect_path = determine_redirect_path(@log)
    @log.destroy

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("service_usage_logs.delete_success")
        prepare_destroy_turbo_stream_state
      end
      format.html { redirect_to redirect_path, notice: t("service_usage_logs.delete_success") }
    end
  end

  private

  def set_room
    @room = @house.rooms.find_by(id: params[:room_id]) if params[:room_id].present?
  end

  def set_selected_service
    @selected_service = @house.services.find_by(id: params[:service_id]) if params[:service_id].present?
  end

  def set_billing_month
    @billing_month = parse_month(params[:month])
  end

  def parse_month(str)
    LandlordServiceUsageLogsIndexBuilder.parse_month(str)
  end

  def set_service_usage_log
    @log = @house.service_usage_logs.find(params[:id])
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

  def prepare_confirm_turbo_stream_state
    @from_room_context = from_room_context?
    if @from_room_context
      @room = @log.room
      @unconfirmed_count = @room.service_usage_logs.unconfirmed.count
    else
      @billing_month = @log.billing_month
      @selected_service = @house.services.find_by(id: params[:service_id]) if params[:service_id].present?
      scope = @house.service_usage_logs.for_month(@billing_month)
      scope = scope.where(service_id: @selected_service.id) if @selected_service
      @unconfirmed_count = scope.unconfirmed.count
    end
  end

  def prepare_destroy_turbo_stream_state
    @from_room_context = from_room_context?
    if @from_room_context
      @room = @log.room
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, room: @room, params: params)
    else
      @billing_month = @log.billing_month
      @logs = LandlordServiceUsageLogsFilter.call(house: @house, params: params.reverse_merge(month: @billing_month.strftime("%Y-%m")))
    end
  end

  def assign_index_data(data)
    @unconfirmed_count = data.unconfirmed_count
    @fixed_services_count = data.fixed_services_count
    @current_tab = data.current_tab
    @fixed_services_summary = data.fixed_services_summary
    @fixed_services = data.fixed_services
    @fixed_variants = data.fixed_variants
    @logs = data.logs
    @services = data.services
    @service_variants = data.service_variants
  end

  def load_floor_and_room_options
    options = LandlordServiceUsageLogsIndexBuilder.floor_and_room_options(house: @house)
    @rooms = options.rooms
    @floors = options.floors
    @room_options = options.room_options
    @room_real_time_variant_ids = options.room_real_time_variant_ids
    @room_occupancy = options.room_occupancy
  end

  def log_params
    params.require(:service_usage_log).permit(
      :room_id, :service_id, :service_variant_id, :service_name, :unit, :unit_price,
      :billing_month, :start_date, :end_date, :prev_reading, :latest_reading,
      :is_confirmed, :reading_photo
    )
  end
end
