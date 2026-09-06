class LandlordRequestFilter < RequestFilter
  def initialize(landlord:, params:)
    super(landlord: landlord, params: params, per_page: 10)
  end
end
