class LandlordPortal::BedsController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :house_in_bed_mode

  BEDS_PER_PAGE = 15

  def index
    @beds = filtered_beds

    # If a user refreshes (F5) or visits directly, render the main house page
    unless turbo_frame_request?
      @active_tab = :beds
      return render "landlord_portal/rooms/index" # Adjust path to your main view
    end

    render :index
  end

  def new
    @form = BedCreationForm.new
    @rooms = @house.rooms.active.includes(:floor).where("rooms.max_slots < ?", BedCreationForm::MAX_SLOTS)
    @floors = @rooms.map(&:floor).uniq.sort_by(&:position)
    @room_options =
      @rooms.map do |room|
        {
          id: room.id,
          floorId: room.floor_id,
          name: "#{room.name} (#{room.max_slots} #{I18n.t('form.bed.self').downcase})",
          maxSlots: room.max_slots,
          rentalUnitId: nil
        }
      end
  end

  def create
    @form = BedCreationForm.new(bed_params)
    @form.room = @house.rooms.active.includes(:floor).find_by(id: bed_params[:room_id])

    @rooms = @house.rooms.active.includes(:floor).where("rooms.max_slots < ?", BedCreationForm::MAX_SLOTS)
    @floors = @rooms.map(&:floor).uniq.sort_by(&:position)
    @room_options =
      @rooms.map do |room|
        {
          id: room.id,
          floorId: room.floor_id,
          name: "#{room.name} (#{room.max_slots} #{I18n.t('form.bed.self').downcase})",
          maxSlots: room.max_slots,
          rentalUnitId: nil
        }
      end

    unless @form.valid?
      flash.now[:alert] = t("errors.unprocessable_entity")
      return render turbo_stream: turbo_stream.replace(
        "new_bed_modal",
        template: "landlord_portal/beds/new"
      ), status: :unprocessable_entity
    end

    room = @form.room

    ActiveRecord::Base.transaction do
      room.create_beds(
        count: @form.beds_count,
        start_at: room.max_slots.to_i,
        rent: 0,
        deposit: 0
      )
    end

    redirect_to landlord_house_rooms_path(@house), notice: t("success_messages.room_created")
  end

  def edit
  end

  def update
  end

  def delete
  end

  def filtered
    @beds = filtered_beds

    render partial: "bed_table", locals: { house: @house, beds: @beds }
  end


  private

  def bed_params
    params.expect(bed_creation_form: [ :beds_count, :floor_id, :room_id ])
  end

  def house_in_bed_mode
    return if @house.bed?

    redirect_to landlord_house_rooms_path(@house),
                alert: t("errors.not_bed_mode")
  end


  def filtered_beds
    scope = @house.beds.active
                  .joins(room: :floor)
                  .includes(
                    room: :floor,
                    staying_tenant: :user
                  )

    case params[:state]
    when "available"
      scope = scope.available
    when "full"
      scope = scope.empty
    end

    scope.order("floors.position ASC, rooms.name ASC, beds.name ASC")
         .page(params[:page])
         .per(BEDS_PER_PAGE)
  end
end
