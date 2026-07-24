class LandlordPortal::RoomsController < LandlordPortal::BaseController
  layout "house_mngment"

  # before_action :set_room, only: %i[ show edit update destroy ]
  load_and_authorize_resource :room, through: :house # @rooms, @room are auto loaded


  def index
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

  def room_params
    params.expect(room: [ :name, :floor_id ])
  end
end
