class LandlordPortal::FloorsController < LandlordPortal::BaseController
  load_and_authorize_resource :floor, through: :house, except: %i[new create]
  before_action :authorize_house_for_floor_creation, only: %i[new create]


  def new
    @floor = Floor.new
  end

  def create
  end


  def update
    if @floor.update(floor_params)
      redirect_to edit_landlord_house_path(@house),
                  notice: t("success_messages.floor_updated")
    else
      redirect_to edit_landlord_house_path(@house),
                  alert: @floor.errors.full_messages.to_sentence
    end
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
