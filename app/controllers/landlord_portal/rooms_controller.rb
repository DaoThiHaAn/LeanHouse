class LandlordPortal::RoomsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :room, through: :house, except: %i[new create]
  # before_action :authorize_house_for_room_creation, only: %i[new create]

  ROOMS_PER_PAGE = 15

  def index
  end

  # Return the filtered table partial
  def filtered
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
    @assets = @room.assets.sorted

    if @house.bed?
      @tenants = @room.all_staying_bed_tenants
      render "show_bedmode"
    else
      @tenants = @room.all_staying_tenants
      render "show_roommode"
    end
  end

  def edit
    prepare_edit_form
  end

  def update
    updater = RoomUpdate.new(
      room: @room,
      house: @house,
      room_attributes: room_params,
      rental_attributes: rental_params,
      service_selections: service_selections
    )

    if updater.call
      redirect_to landlord_house_rooms_path(@house),
                  notice: t("success_messages.room_updated")
    else
      prepare_edit_form(service_selections: service_selections)
      flash.now[:alert] = t("errors.unprocessable_entity")
      render turbo_stream: turbo_stream.replace(
        "edit_room_modal",
        template: "landlord_portal/rooms/edit"
      ), status: :unprocessable_entity
    end
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

  def prepare_edit_form(service_selections: nil)
    @services = @house.services.includes(:service_variants)
    @applied_service_variants_by_service_id = if service_selections
      selected_variant_ids = service_selections.to_h.filter_map do |_service_id, selection|
        selection["variant_id"] if selection["selected"].to_s == "1"
      end
      @house.service_variants.where(id: selected_variant_ids).index_by(&:service_id)
    else
      @room.room_services.includes(:service_variant).index_by do |room_service|
        room_service.service_variant.service_id
      end.transform_values(&:service_variant)
    end

    rental_unit = if @house.bed?
      @room.beds.active.includes(:rental_unit).first&.rental_unit
    else
      @room.rental_unit
    end
    @room.rent ||= rental_unit&.rent
    @room.deposit ||= rental_unit&.deposit
  end

  # Filter rooms based on url params
  def filtered_rooms
    scope = @house.rooms.active.includes(:floor)

    case params[:state]
    when "available"
      scope = scope.available
    when "full"
      scope = scope.full
    when "not_empty", "occupied"
      scope = scope.not_empty
    when "empty"
      scope = scope.empty
    end

    scope.order("floors.position ASC, rooms.name ASC")
         .page(params[:page])
         .per(ROOMS_PER_PAGE)
  end


  def set_house_from_room
    @house ||= @room.house
  end
end
