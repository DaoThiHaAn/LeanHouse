class LandlordPortal::ContractsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :contract, through: :house, except: %i[new create index]


  def new
    @contract = Contract.new
  end

  def create
  end

  def show
  end

  def index
    @unsigned_tenants = @house.all_linked_tenants(signed_contract: true)
    # Extract all contracts of only current staying tenants
    @contracts = @house.all_current_contracts.expiring_soonest
  end

  def destroy
  end
end
