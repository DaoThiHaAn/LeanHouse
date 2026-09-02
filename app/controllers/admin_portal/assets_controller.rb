module AdminPortal
  class AssetsController < BaseController
    def index
      @house = House.active.includes(
        landlord: :user,
        floors: :rooms
      ).find(params[:house_id])

      @category_filter = params[:category].presence
      @status_filter = params[:status].presence

      assets_scope = @house.assets.includes(room: :floor, maintenance_logs: []).order("rooms.name ASC, assets.created_at DESC")
      assets_scope = assets_scope.where(category: @category_filter) if @category_filter.present?
      assets_scope = assets_scope.where(status: @status_filter) if @status_filter.present?

      @assets = assets_scope
      @total_assets_count = @house.assets.count
      @normal_count = @house.assets.where(status: "normal").count
      @damaged_count = @house.assets.where(status: %w[damaged under_repair]).count
      @total_price = @house.assets.sum(:price)

      @available_categories = @house.assets.distinct.order(:category).pluck(:category).compact.map do |cat|
        [ I18n.t("enums.asset.categories.#{cat}", default: cat.humanize), cat ]
      end
    end
  end
end
