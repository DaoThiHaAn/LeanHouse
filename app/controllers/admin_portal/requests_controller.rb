module AdminPortal
  class RequestsController < BaseController
    before_action :set_request, only: [ :show ]

    def index
      @query = params[:q].presence || params[:query].presence
      @status = params[:status].presence
      @request_type = params[:request_type].presence
      @from_date = params[:from_date].presence
      @to_date = params[:to_date].presence

      base_scope = RequestFilter.new(params: params.except(:status)).unpaginated_scope
      @pending_count = base_scope.pending.count
      @handling_count = base_scope.handling.count

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
