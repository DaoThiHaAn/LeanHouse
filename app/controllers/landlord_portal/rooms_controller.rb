class LandlordPortal::RoomsController < LandlordPortal::BaseController
  before_action :set_room, only: %i[ show edit update destroy ]

  def index
  end


  def show
    render :show
  end

  def edit
  end

  def update
  end

  def destroy
  end

  private

  def set_room
  end
end
