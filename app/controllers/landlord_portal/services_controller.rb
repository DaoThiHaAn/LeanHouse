class LandlordPortal::ServicesController < LandlordPortal::BaseController
  layout "house_mngment"

  def show
    render :show
  end

  def index
    @services = @house.services
    render :index
  end

  def new
  end

  def create
  end
end
