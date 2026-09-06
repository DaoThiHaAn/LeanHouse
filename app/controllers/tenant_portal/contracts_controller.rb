class TenantPortal::ContractsController < TenantPortal::BaseController
  skip_before_action :require_linked_house!, only: [ :index, :show ]

  # Show the latest active contract or a specific contract if id is provided
  def show
    if params[:id].present?
      @contract = @tenant.contracts.find_by(id: params[:id])
      if @contract
        @house = @contract.house
        return render :show
      end
    end

    return render("tenant_portal/shared/no_house", status: :ok) unless @tenant_stay

    @contract = @tenant.latest_active_contract
    if @contract.present?
      @house = @contract.house
      render :show
    else
      render "no_contract"
    end
  end

  # Show all contracts linked with the tenant ordered by descending start date
  def index
    @contracts = @tenant.contracts
                        .includes(:house, landlord: :user)
                        .latest_started
                        .page(params[:page])
                        .per(10)
    @active_contract = @tenant.latest_active_contract
  end
end
