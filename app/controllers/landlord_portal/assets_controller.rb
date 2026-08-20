class LandlordPortal::AssetsController < LandlordPortal::BaseController
  layout "house_mngment"

  # load_and_authorize_resource :asset, through: :house, except: %i[new create]

  def index
    @assets = @house.assets.sorted
  end

  def show
  end

  def new
  end

  def edit
  end

  def create
  end

  def update
  end

  def destroy
  end
end
