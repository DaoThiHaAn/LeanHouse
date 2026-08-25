class LandlordPortal::AssetsController < LandlordPortal::BaseController
  layout "house_mngment"

  load_and_authorize_resource :asset, through: :house, except: %i[new create index]

  ASSETS_PER_PAGE = 15

  def index
    @assets = @house.assets.includes(room: :floor).sorted

    @available_categories = @house.assets.distinct.order(:category).pluck(:category).compact.map do |cat|
      [ I18n.t("enums.asset.categories.#{cat}", default: cat), cat ]
    end
  end

  def filtered
    @assets = filtered_assets
    render partial: "asset_table", locals: { house: @house, assets: @assets }
  end


  def new
    @asset = Asset.new
    prepare_form_fields
  end

  def edit
    prepare_form_fields
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
    if @asset.update(asset_params)
      flash.now[:notice] = t("success_messages.asset_updated")
      render turbo_stream: [
        # 1. Cập nhật đúng dòng asset vừa sửa
        turbo_stream.replace(
          ActionView::RecordIdentifier.dom_id(@asset),
          partial: "landlord_portal/assets/asset_row",
          locals: { house: @house, asset: @asset }
        ),
        # 2. Đóng / clear modal
        turbo_stream.append(
          "events",
          partial: "layouts/shared_components/event",
          locals: { event: "close-modal" }
        ),
        # 3. Hiển thị thông báo flash
        turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
      ]
    else
      prepare_form_fields
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @asset.destroy
    flash.now[:notice] = t("success_messages.asset_deleted")
    render turbo_stream: [
      # 1. Xóa trực tiếp dòng tài sản khỏi bảng dựa vào dom_id (ví dụ: #asset_12)
      turbo_stream.remove(ActionView::RecordIdentifier.dom_id(@asset)),
      # 2. Cập nhật thông báo flash màu xanh trên đầu trang
      turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
    ]
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
    params.require(:asset).permit(:room_id, :brand, :model, :price, :purchased_at, :note, :status)
  end

  def filtered_assets
    scope = @house.assets.includes(room: :floor)
    scope = scope.where(category: params[:category]) if params[:category].present?
    scope = scope.where(status: params[:status]) if params[:status].present?

    scope.sorted
          .page(params[:page])
          .per(ASSETS_PER_PAGE)
  end
end
