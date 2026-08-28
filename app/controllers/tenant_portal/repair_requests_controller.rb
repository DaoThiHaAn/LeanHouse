class TenantPortal::RepairRequestsController < TenantPortal::BaseController
  def new
    @repair_request = RepairRequest.new
  end

  def create
    @repair_request = RepairRequestSubmission.call(
      tenant: @tenant,
      house: @house,
      tenant_stay: @tenant_stay,
      params: repair_request_params
    )

    redirect_to tenant_requests_path, notice: t("success_messages.repair_created_success", default: "Gửi yêu cầu sửa chữa thành công!")
  rescue ActiveRecord::RecordInvalid => e
    @repair_request = e.record.is_a?(RepairRequest) ? e.record : RepairRequest.new(repair_request_params.except(:images, :video))
    render :new, status: :unprocessable_entity
  end

  private

  def repair_request_params
    params.require(:repair_request).permit(
      :title,
      :content,
      :video,
      images: []
    )
  end
end
