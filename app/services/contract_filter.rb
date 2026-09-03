class ContractFilter
  CONTRACTS_PER_PAGE = 15

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
      .preload(tenant: :user)
      .order(start_date: :desc, id: :desc)
      .page(page)
      .per(CONTRACTS_PER_PAGE)
  end

  private

  attr_reader :house, :query, :state, :page

  def base_scope
    house.contracts
  end

  # Tìm theo tên khách thuê, số điện thoại hoặc tên hợp đồng
  def apply_search(scope)
    return scope if query.blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    scope.joins(tenant: :user).where(
      "unaccent(users.fullname) ILIKE unaccent(:q) OR users.tel ILIKE :q OR unaccent(contracts.name) ILIKE unaccent(:q)",
      q: q
    )
  end

  # Lọc theo trạng thái
  def apply_state(scope)
    case state
    when "active"
      scope.where(end_date: nil).where("contracts.due_date >= ?", Date.current)
    when "nearly-due", "nearly_due"
      scope.where(end_date: nil, contracts: { due_date: Date.current..(Date.current + Contract::NEARLY_DUE_DAYS.days) })
    when "overdue"
      scope.where(end_date: nil).where("contracts.due_date < ?", Date.current)
    when "finished"
      scope.where.not(end_date: nil)
    else
      scope
    end
  end
end
