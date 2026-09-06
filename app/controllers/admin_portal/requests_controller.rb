module AdminPortal
  class RequestsController < BaseController
    before_action :set_request, only: [ :show ]

    def index
      @total_requests_count = Request.count
      @pending_count = Request.pending.count
      @handling_count = Request.handling.count
      @completed_count = Request.where(status: %i[completed approved]).count
      @rejected_count = Request.rejected.count
      @overdue_count = Request.overdue.count

      @query = params[:q].presence || params[:query].presence
      @status = params[:status].presence
      @request_type = params[:request_type].presence
      @from_date = params[:from_date].presence
      @to_date = params[:to_date].presence

      @requests = RequestFilter.call(params: params)
    end

    def show
    end

    private

    def set_request
      @request = Request.includes(:house, :requestable, :resolved_by, tenant: :user).find(params[:id])
    end
  end
end
