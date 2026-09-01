class LandlordPortal::VehiclesController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_vehicle, only: %i[destroy]

  def index
    @vehicles = @house.vehicles.includes(tenant: :user).sorted
    @available_types = available_types_options
  end

  def filtered
    @vehicles = @house.vehicles.includes(tenant: :user)
                              .by_type(params[:vehicle_type])
                              .search(params[:query])
                              .sorted

    render partial: "vehicle_table", locals: { house: @house, vehicles: @vehicles }
  end

  def destroy
    VehicleDeletion.call(
      vehicle: @vehicle,
      actor_user: current_user,
      reason: params[:reason]
    )

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("success_messages.vehicle_deleted", default: "Đã xóa phương tiện thành công!")
      end
      format.html do
        redirect_to landlord_house_vehicles_path(@house), notice: t("success_messages.vehicle_deleted", default: "Đã xóa phương tiện thành công!")
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = e.record.errors.full_messages.to_sentence.presence || t("errors.vehicle_delete_failed", default: "Không thể xóa phương tiện!")
        render turbo_stream: turbo_stream.update("flash", partial: "layouts/shared_components/flash_message"), status: :unprocessable_entity
      end
      format.html do
        redirect_to landlord_house_vehicles_path(@house), alert: e.record.errors.full_messages.to_sentence.presence || t("errors.vehicle_delete_failed", default: "Không thể xóa phương tiện!")
      end
    end
  end

  private

  def set_vehicle
    @vehicle = @house.vehicles.find(params[:id])
  end

  def available_types_options
    Vehicle.vehicle_types.keys.map do |t|
      [ I18n.t("enums.vehicle.vehicle_type.#{t}", default: t.humanize), t ]
    end
  end
end
