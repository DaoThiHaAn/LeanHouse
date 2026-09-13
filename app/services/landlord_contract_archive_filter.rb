class LandlordContractArchiveFilter
  CONTRACTS_PER_PAGE = 10

  def self.call(...)
    new(...).call
  end

  def initialize(landlord:, params:)
    @landlord = landlord
    @query = (params[:q] || params[:query])&.strip
    @house_id = params[:house_id].presence
    @page = params[:page]
  end

  def call
    scope = base_scope
    scope = apply_house(scope)
    scope = apply_search(scope)

    scope
      .includes(:house, tenant: :user)
      .order(start_date: :desc, id: :desc)
      .page(page)
      .per(CONTRACTS_PER_PAGE)
  end

  private

  attr_reader :landlord, :query, :house_id, :page

  def base_scope
    landlord.contracts.joins(:house).where(houses: { is_deleted: true })
  end

  def apply_house(scope)
    return scope if house_id.blank?

    scope.where(house_id: house_id)
  end

  def apply_search(scope)
    return scope if query.blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.joins(tenant: :user).where(
      "unaccent(users.fullname) ILIKE unaccent(:q) OR users.tel ILIKE :q OR unaccent(contracts.name) ILIKE unaccent(:q)",
      q: q
    )
  end
end
