class LandlordPortal::RoomsController < LandlordPortal::BaseController
  before_action :set_house, only: %i[ index new create ]
  before_action :set_room, only: %i[ show edit update destroy ]

  def index
    @other_houses = @landlord.get_other_houses(@house.id).select(:id, :name)
  end

  def new
  end

  def create
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
