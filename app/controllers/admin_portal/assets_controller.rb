module AdminPortal
  class AssetsController < BaseController
    before_action :set_house

    def index
      @category_filter = params[:category].presence
      @status_filter = params[:status].presence

      @assets = HouseAssetsFilter.call(house: @house, params: params)
      @stats = @house.asset_summary_stats
      @available_categories = @house.available_asset_categories
    end

    private

    def set_house
      @house = House.active.includes(landlord: :user, floors: :rooms).find(params[:house_id])
    end
  end
end
