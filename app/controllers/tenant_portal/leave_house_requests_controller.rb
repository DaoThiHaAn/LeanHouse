class TenantPortal::LeaveHouseRequestsController < TenantPortal::BaseController
  def create
    @leave_house_request = LeaveHouseRequestSubmission.call(
      tenant: @tenant,
      house: @house,
      tenant_stay: @tenant_stay
    )

    redirect_to tenant_requests_path, notice: t("success_messages.leave_house_created_success", default: "Gửi yêu cầu rời nhà thành công! Vui lòng chờ Chủ nhà xét duyệt.")
  rescue ActiveRecord::RecordInvalid => e
    redirect_to tenant_requests_path, alert: e.record.errors.full_messages.to_sentence.presence || t("errors.cannot_perform_action", default: "Không thể thực hiện yêu cầu!")
  end
end
