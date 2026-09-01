class LandlordPortal::RequestsController < LandlordPortal::BaseController
  before_action :set_request, only: %i[show handle]

  def index
    @houses = @landlord.houses.sorted
    @stats = LandlordRequestStatsService.call(landlord: @landlord)
  end

  def filtered
    @requests = LandlordRequestFilter.call(
      landlord: @landlord,
      params: params
    )

    render partial: "request_table",
           locals: { requests: @requests }
  end

  def show
  end

  def handle
    RequestHandling.call(
      request: @request,
      landlord_user: current_user,
      decision: params[:decision],
      rejection_reason: params[:rejection_reason]
    )

    set_request

    flash_message = case @request.status
    when "approved" then t("success_messages.request_approved", default: "Duyệt yêu cầu thành công!")
    when "handling" then t("success_messages.request_handling", default: "Tiếp nhận xử lý yêu cầu thành công!")
    when "completed" then t("success_messages.request_completed", default: "Xác nhận hoàn thành yêu cầu thành công!")
    when "rejected" then t("success_messages.request_rejected", default: "Từ chối yêu cầu thành công!")
    else t("success_messages.request_updated", default: "Cập nhật yêu cầu thành công!")
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = flash_message
        render turbo_stream: [
          turbo_stream.replace(
            "request_detail_modal",
            template: "landlord_portal/requests/show"
          ),
          turbo_stream.replace(
            "request_row_#{@request.id}",
            partial: "landlord_portal/requests/request_row",
            locals: { request: @request }
          ),
          turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
        ]
      end
      format.html do
        redirect_to landlord_requests_path, notice: flash_message
      end
    end
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    flash.now[:alert] = @request.errors.full_messages.to_sentence.presence || e.message
    render_modal_error
  end

  private

  def set_request
    @request = @landlord.requests
      .includes(:house, :requestable, :resolved_by, tenant: :user)
      .find(params[:id])
  end

  def render_modal_error
    render turbo_stream: [
      turbo_stream.replace("request_detail_modal", template: "landlord_portal/requests/show"),
      turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
    ], status: :unprocessable_entity
  end
end
