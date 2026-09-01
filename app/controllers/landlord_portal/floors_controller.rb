class LandlordPortal::FloorsController < LandlordPortal::BaseController
  load_and_authorize_resource :floor, through: :house, except: %i[new create]
  # before_action :authorize_house_for_floor_creation, only: %i[new create]
  before_action :check_max_floors, only: [ :new ]

  MAX_FLOORS = 50

  def new
    @floor = Floor.new
    @floor.rooms.build
  end

  def create
    # Request comes from a turbo frame

    @floor = @house.floors.new(floor_params)

    Floor.transaction do
      @floor.save!

      @floor.generate_rooms!(
        mode: @house.room? ? :room : :bed,
        count: params[:floor][:rooms_count].to_i,
        area: params[:floor][:room_area].to_f,
        max_slots: params[:floor][:room_capacity].to_i,
        rent: params[:floor][:room_rent].to_i,
        deposit: params[:floor][:room_deposit].to_i
      )
    end

    flash.now[:notice] = t("success_messages.floor_created")
    respond_to do |format|
      format.turbo_stream
    end
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end


  def update
    # The request comes from inside a turbo frame
    if @floor.update(floor_params)
      flash.now[:notice] = t("success_messages.floor_updated")
      respond_to do |format|
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.turbo_stream { render :update, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @floor.destroy

    redirect_to edit_landlord_house_path(@house),
                notice: t("success_messages.floor_deleted")
  end

  def check_delete
    if @floor.can_delete?
      render "check_delete_confirm"
    else
      render "check_delete_blocked"
    end
  end

  def sort
    Floor.transaction do
      offset = @house.floors.count + 100 # Bypass the unique constraint

      @house.floors.update_all(Arel.sql("position = position + #{offset.to_i}"))
      params[:floor_ids].each_with_index do |id, index|
        @house.floors.where(id: id).update_all(position: index + 1)
      end
    end

    flash.now[:notice] = t("success_messages.floor_sorted")

    render turbo_stream: turbo_stream.update(
      "flash",
      partial: "layouts/shared_components/flash_message"
    )
  end

  private

  def floor_params
    params.require(:floor).permit(:name)
  end

  def room_generation_params
    params.require(:floor).permit(
      :room_area,
      :room_rent,
      :room_capacity,
      :room_deposit
    )
  end

  def authorize_house_for_floor_creation
    authorize! :update, @house
    authorize! :create, Floor
  end

  def check_max_floors
    return if @house.floors_count < MAX_FLOORS
    flash.now[:alert] = t("form.floor.reach_max")

    render turbo_stream: turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        )
  end
end
