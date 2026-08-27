class TenantPortal::RequestsController < TenantPortal::BaseController
  # Allow viewing the list even if not currently staying in any house
  skip_before_action :require_linked_house!, only: [ :index ]

  def index
    @requests = @tenant.requests.includes(:requestable).recent
  end
end
