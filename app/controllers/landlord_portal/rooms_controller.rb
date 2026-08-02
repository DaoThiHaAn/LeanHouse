class LandlordPortal::RoomsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :room, through: :house, except: %i[new create]
  before_action :authorize_house_for_room_creation, only: %i[new create]

  def index
  end

  # Return the table partial in bed mode
  def table_bed
    @rooms = filtered_rooms_bed_mode

    render partial: "room_table_bed",
           locals: { house: @house, rooms: @rooms }
  end

  # Return the table partial in room mode
  def table
    @rooms = filtered_rooms

    render partial: "room_table_bed",
           locals: { house: @house, rooms: @rooms }
  end

  def new
    @room = Room.new
  end

  def create
  end

  def show
    @floor = @room.floor
    @room_services = @room.room_services

    if @house.bed?
      render "show_bedmode"
    else
      render "show_roommode"
    end
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

  def authorize_house_for_room_creation
    authorize! :update, @house
  end

  def filtered_rooms_bed_mode
    scope = @house.rooms.includes(:floor)

    case params[:state]
    when "available"
      scope = scope.available
    when "full"
      scope = scope.full
    end

    scope.order("floors.name ASC, rooms.name ASC")
         .page(params[:page])
         .per(20)
  end

  # TODO
  def filtered_rooms
    scope = @house.rooms.sorted.includes(:floor)

    case params[:state]
    when "available"
      scope = scope.available
    when "full"
      scope = scope.full
    end

    scope.page(params[:page]).per(20)
  end

  def set_house_from_room
    @house ||= @room.house
  end
end
