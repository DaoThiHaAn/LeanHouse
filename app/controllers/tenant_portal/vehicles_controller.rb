class TenantPortal::VehiclesController < TenantPortal::BaseController
  before_action :set_vehicle, only: %i[destroy]

  def index
    @vehicles = @tenant.vehicles.where(house: @house).sorted
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
        render turbo_stream: [
          turbo_stream.remove("vehicle_card_#{@vehicle.id}"),
          turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
        ]
      end
      format.html do
        redirect_to tenant_vehicles_path, notice: t("success_messages.vehicle_deleted", default: "Đã xóa phương tiện thành công!")
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = e.record.errors.full_messages.to_sentence.presence || t("errors.vehicle_delete_failed", default: "Không thể xóa phương tiện!")
        render turbo_stream: turbo_stream.update("flash", partial: "layouts/shared_components/flash_message"), status: :unprocessable_entity
      end
      format.html do
        redirect_to tenant_vehicles_path, alert: e.record.errors.full_messages.to_sentence.presence || t("errors.vehicle_delete_failed", default: "Không thể xóa phương tiện!")
      end
    end
  end

  private

  def set_vehicle
    @vehicle = @tenant.vehicles.where(house: @house).find(params[:id])
  end
end
