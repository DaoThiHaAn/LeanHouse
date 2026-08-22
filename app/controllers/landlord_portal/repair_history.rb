class LandlordPortal::RepairHistoryController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :asset, through: :house, except: %i[new create]

  def index
  end

  def edit
  end

  def new
  end
end
