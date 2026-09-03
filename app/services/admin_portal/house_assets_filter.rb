module AdminPortal
  class HouseAssetsFilter
    ASSETS_PER_PAGE = 10

    def self.call(...)
      new(...).call
    end

    def initialize(house:, params:)
      @house = house
      @category = params[:category].presence
      @status = params[:status].presence
      @page = params[:page]
    end

    def call
      scope = house.assets
                   .includes(room: :floor, maintenance_logs: [])
                   .order("rooms.name ASC, assets.created_at DESC")

      scope = scope.where(category: category) if category.present?
      scope = scope.where(status: status) if status.present?

      scope.page(page).per(ASSETS_PER_PAGE)
    end

    private

    attr_reader :house, :category, :status, :page
  end
end
