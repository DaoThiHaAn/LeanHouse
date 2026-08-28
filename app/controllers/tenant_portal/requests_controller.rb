class TenantPortal::RequestsController < TenantPortal::BaseController
  # Allow viewing the list, filtered partial, and detail even if not currently staying in any house
  skip_before_action :require_linked_house!, only: [ :index, :filtered, :show ]

  def index
    @linked_houses = @tenant.linked_houses
    @selected_house_id = params.key?(:house_id) ? params[:house_id] : (@house&.id&.to_s || "")
  end

  def filtered
    @requests = TenantRequestFilter.call(
      tenant: @tenant,
      params: params,
      current_house_id: @house&.id
    )

    render partial: "request_table",
           locals: { requests: @requests }
  end

  def show
    @request = @tenant.requests.includes(:house, :resolved_by, :requestable).find(params[:id])
  end
end
