class TenantPortal::VehicleRequestsController < TenantPortal::BaseController
  def new
    @vehicle_request = VehicleRequest.new
  end

  def create
    @vehicle_request = VehicleRequestSubmission.call(
      tenant: @tenant,
      house: @house,
      tenant_stay: @tenant_stay,
      params: vehicle_request_params,
      accept_terms: params[:accept_terms]
    )

    redirect_to tenant_requests_path, notice: t("request.vehicle_created_success")
  rescue ActiveRecord::RecordInvalid => e
    @vehicle_request = e.record.is_a?(VehicleRequest) ? e.record : VehicleRequest.new(vehicle_request_params)
    render :new, status: :unprocessable_entity
  end

  private

  def vehicle_request_params
    params.require(:vehicle_request).permit(
      :license_plate,
      :vehicle_type,
      :brand,
      :model,
      :vehicle_photo,
      :registration_card_image
    )
  end
end
