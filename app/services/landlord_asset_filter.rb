class LandlordAssetFilter
  ASSETS_PER_PAGE = 15

  def self.call(...)
    new(...).call
  end

  def initialize(house:, params:)
    @house = house
    @category = params[:category]
    @status = params[:status]
    @page = params[:page]
  end

  def call
    scope = house.assets.includes(room: :floor)
    scope = scope.where(category: category) if category.present?
    scope = scope.where(status: status) if status.present?

    scope.sorted
         .page(page)
         .per(ASSETS_PER_PAGE)
  end

  private

  attr_reader :house, :category, :status, :page
end
