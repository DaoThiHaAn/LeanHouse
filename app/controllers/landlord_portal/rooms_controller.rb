class LandlordPortal::RoomsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :room, through: :house, except: %i[new create]
  before_action :authorize_house_for_room_creation, only: %i[new create]

  def index
  end

  # Return the filtered table partial
  def filtered_table
    @rooms = filtered_rooms

    if @house.room?
      render partial: "room_table",
            locals: { house: @house, rooms: @rooms }
    else
      render partial: "room_table_bed",
           locals: { house: @house, rooms: @rooms }
    end
  end

  def new
    @room = Room.new
    @floors = @house.floors.available
    @services = @house.services.includes(:service_variants)
  end

  def create
    @room = @house.rooms.build(room_params)
    @room.max_slots = 0 if @house.bed?
    @room.service_selections = service_selections

    unless @room.valid?(:service_selection)
      @floors = @house.floors.available
      @services = @house.services.includes(:service_variants)
      flash.now[:alert] = t("errors.unprocessable_entity")
      return render :new,
            status: :unprocessable_entity
    end

    ActiveRecord::Base.transaction do
      @room.save!

      if @house.room?
        @room.create_rental_unit!(
          rent: rental_params[:rent],
          deposit: rental_params[:deposit]
        )
      else
        @room.create_beds(
          count: room_params[:max_slots].to_i,
          rent: rental_params[:rent],
          deposit: rental_params[:deposit]
        )
      end

      @room.add_services(
        house: @house,
        selections: service_selections
      )
    end

    redirect_to landlord_house_rooms_path(@house),
                notice: t("success_messages.room_created")
  end

  def show
    @floor = @room.floor
    @room_services = @room.room_services.includes(service_variant: :service)

    if @house.bed?
      @tenants = @room.all_staying_bed_tenants
      render "show_bedmode"
    else
      @tenants = @room.all_staying_tenants
      render "show_roommode"
    end
  end

  def edit
    @services = @house.services.includes(:service_variants)
  end

  def update
  end

  def destroy
  end

  private

  def room_params
    params.expect(room: [
      :name,
      :floor_id,
      :area,
      :max_slots
    ])
  end

  def rental_params
    params.expect(room: [
      :rent,
      :deposit
    ])
  end

  def service_selections
    params.expect(
      room: [
        service_selections: {}
      ]
    )[:service_selections]
  end

  def authorize_house_for_room_creation
    authorize! :update, @house
  end

  def filtered_rooms
    scope = @house.rooms.active.includes(:floor)

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
  def filtered_beds
  end

  def set_house_from_room
    @house ||= @room.house
  end
end
