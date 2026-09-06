class TenantRequestFilter < RequestFilter
  def initialize(tenant:, params:, current_house_id: nil)
    super(tenant: tenant, params: params, current_house_id: current_house_id, per_page: 10)
  end
end
