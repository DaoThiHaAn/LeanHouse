class TenantPortal::ContractsController < TenantPortal::BaseController
  def show
    unless @tenant_stay.has_contract
      return render "no_contract"
    end
    @contract = @tenant.latest_contract
    render :show
  end

  def old_index
    # Show all old contracts
  end
end
