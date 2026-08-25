class TenantPortal::ContractsController < TenantPortal::BaseController
  def show
    unless @tenant_stay.has_contract
      return render "no_tenant"
    end

    render :show
  end
end
