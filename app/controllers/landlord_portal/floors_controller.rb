class LandlordPortal::FloorsController < LandlordPortal::BaseController
  load_and_authorize_resource :floor, through: :house, except: %i[new create]
  before_action :authorize_house_for_floor_creation, only: %i[new create]


  def new
    @floor = Floor.new
  end

  def create
    @floor = @house.floors.new(floor_params)
    requested_rooms = params[:floor][:rooms_count].to_i

    Floor.transaction do
      @floor.save!

      if @house.room?
        @floor.generate_rooms_in_room_mode!(
          count: requested_rooms
        )
      end
    end

    redirect edit_landlord_house_path(@house), notice: t("success_messages.floor_created")

  rescue ActiveRecord::RecordInvalid
    render turbo_stream: [
        turbo_stream.replace(
          "new_floor_modal",
          partial: "landlord_portal/floors/new",
          locals: {
            floor: @floor,
            house: @house
          }),
        turbo_stream.update(
          "flash",
          partial: "layouts/shared_components/flash_message"
        ) ],
        status: :unprocessable_entity
  end


  def update
    # The request comes from inside a turbo frame

    if @floor.update(floor_params)
        flash.now[:notice] = t("success_messages.floor_updated")
    else
        flash.now[:alert] = @floor.errors[:name].to_sentence
    end

    render turbo_stream: [
      turbo_stream.replace(
        helpers.dom_id(@floor),
        partial: "landlord_portal/floors/floor",
        locals: {
          floor: @floor,
          house: @house,
          index: @floor.position - 1
        }),
      turbo_stream.update(
        "flash",
        partial: "layouts/shared_components/flash_message"
      ) ],
    status: (@floor.errors.any? ? :unprocessable_entity : :ok)
  end

  def destroy
    @floor.destroy

    redirect_to edit_landlord_house_path(@house),
                notice: t("success_messages.floor_deleted")
  end

  def check_delete
    @can_delete = @floor.can_delete?
  end

  def sort
    Floor.transaction do
      offset = @house.floors.count + 100 # Bypass the unique constraint

      @house.floors.update_all("position = position + #{offset}")

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
    params.expect(floor: [ :name ])
  end

  def authorize_house_for_floor_creation
    authorize! :update, @house
    authorize! :create, Floor
  end
end
