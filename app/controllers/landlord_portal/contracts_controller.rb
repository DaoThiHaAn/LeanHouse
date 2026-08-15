class LandlordPortal::ContractsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :contract, through: :house, except: %i[new create]


  def new
    @contract = Contract.new
  end

  def create
  end

  def show
  end

  def index
  end
end
