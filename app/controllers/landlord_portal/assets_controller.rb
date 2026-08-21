class LandlordPortal::AssetsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :asset, through: :house, except: %i[new create]

  def index
    @assets = @house.assets.sorted
  end

  def show
  end

  def new
    @asset = Asset.new
    prepare_form_fields
  end

  def edit
  end

  def create
     # Handle "other" category option case
     category =
      if params[:category_select] == "other"
                params[:custom_category]&.strip
      else
          params[:category_select]
      end
    @asset = Asset.new(asset_params.merge(category: category))

    if @asset.save
      redirect_to landlord_house_assets_path(@house), notice: t("success_messages.asset_created")
    else
      prepare_form_fields
      render :new, status: :unprocessable_entity
    end
  end

  def update
  end

  def destroy
  end

  private

  def prepare_form_fields
    # Get category options
    @category_options = Asset.category_options

    # Filter all active rooms group by floors
    @rooms = @house.rooms.active.includes(:floor).sorted
    @floors = @rooms.map(&:floor).uniq.sort_by(&:position)
    @room_options = @rooms.map do |room|
        {
          id: room.id,
          floorId: room.floor_id,
          name: room.name
        }
    end
  end

  def asset_params
    params.require(:asset).permit(:room_id, :brand, :model, :price, :purchased_at, :note)
  end
end
