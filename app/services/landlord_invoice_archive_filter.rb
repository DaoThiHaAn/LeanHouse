class LandlordInvoiceArchiveFilter
  INVOICES_PER_PAGE = 10

  def self.call(...)
    new(...).call
  end

  def initialize(landlord:, params:)
    @landlord = landlord
    @query = (params[:q] || params[:query])&.strip
    @house_id = params[:house_id].presence
    @month = params[:month].presence
    @page = params[:page]
  end

  def call
    scope = base_scope
    scope = apply_house(scope)
    scope = apply_month(scope)
    scope = apply_search(scope)

    scope
      .includes(:house, :room, tenant: :user)
      .order(billing_month: :desc, created_at: :desc, id: :desc)
      .page(page)
      .per(INVOICES_PER_PAGE)
  end

  private

  attr_reader :landlord, :query, :house_id, :month, :page

  def base_scope
    Invoice.joins(:house).where(houses: { landlord_id: landlord.id, is_deleted: true })
  end

  def apply_house(scope)
    return scope if house_id.blank?

    scope.where(house_id: house_id)
  end

  def apply_month(scope)
    return scope if month.blank?

    parsed_month = begin
      Date.parse("#{month}-01")
    rescue StandardError
      Date.parse(month.to_s) rescue nil
    end

    return scope unless parsed_month

    scope.where(billing_month: parsed_month.beginning_of_month)
  end

  def apply_search(scope)
    return scope if query.blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.left_joins(:room, tenant: :user).where(
      "invoices.code ILIKE :q OR unaccent(invoices.title) ILIKE unaccent(:q) OR unaccent(users.fullname) ILIKE unaccent(:q) OR users.tel ILIKE :q OR unaccent(rooms.name) ILIKE unaccent(:q)",
      q: q
    )
  end
end
