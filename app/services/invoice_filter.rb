class InvoiceFilter
  INVOICES_PER_PAGE = 15

  def self.call(...)
    new(...).call
  end

  def initialize(house:, params:)
    @house = house
    @query = (params[:q] || params[:query])&.strip
    @state = params[:state]
    @page = params[:page]
  end

  def call
    scope = base_scope
    scope = apply_search(scope)
    scope = apply_state(scope)

    scope
      .preload(:room, :paid_by, tenant: :user)
      .order(billing_month: :desc, id: :desc)
      .page(page)
      .per(INVOICES_PER_PAGE)
  end

  private

  attr_reader :house, :query, :state, :page

  def base_scope
    house.invoices
  end

  # Tìm theo mã hóa đơn, tên phòng hoặc tên khách thuê
  def apply_search(scope)
    return scope if query.blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.left_joins(:room, tenant: :user).where(
      "invoices.code ILIKE :q OR unaccent(rooms.name) ILIKE unaccent(:q) OR unaccent(users.fullname) ILIKE unaccent(:q)",
      q: q
    )
  end

  # Lọc theo trạng thái
  def apply_state(scope)
    case state
    when "paid"
      scope.where(status: :paid)
    when "pending"
      scope.where(status: :pending)
    when "overdue"
      scope.where(status: :overdue)
    when "cancelled"
      scope.where(status: :cancelled)
    else
      scope
    end
  end
end
