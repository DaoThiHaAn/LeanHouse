# Filter tenants to display in views
class TenantFilter
  TENANTS_PER_PAGE = 15

  def self.call(...)
    new(...).call
  end

  def initialize(house:, params:)
    @house = house
    @query = params[:query]&.strip
    @contract_state = params[:contract_state]
    @residence_state = params[:residence_state]
    @page = params[:page]
  end

  def call
    scope = base_scope
    scope = apply_search(scope)
    scope = apply_contract_filters(scope)

    scope
      .includes(:user, :contracts, tenant_stays: { rental_unit: [ :rentable, room: :floor ] })
      .name_sorted
      .distinct
      .page(page)
      .per(TENANTS_PER_PAGE)
  end

  private

  attr_reader :house, :query, :contract_state, :residence_state, :page

  # Base scope: signed tenants with active stays in this house
  def base_scope
    rentable_records = house.room? ? house.rooms : house.beds
    rental_units = RentalUnit.where(rentable: rentable_records)

    Tenant
      .joins(:tenant_stays)
      .where(tenant_stays: {
        rental_unit_id: rental_units,
        checkout_at: nil,
        has_contract: true
      })
  end

  def apply_search(scope)
    return scope if query.blank?

    scope.search(query)
  end

  def apply_contract_filters(scope)
    return scope unless filtering_by_contract?

    scope = scope.joins(:contracts).where(contracts: { house_id: house.id })
    scope = apply_contract_state(scope)
    apply_residence_state(scope)
  end

  def apply_contract_state(scope)
    case contract_state
    when "overdue"
      scope.merge(Contract.overdue)
    when "nearly-due", "nearly_due"
      scope.merge(Contract.nearly_due)
    else
      scope
    end
  end

  def apply_residence_state(scope)
    case residence_state
    when "none"
      scope.merge(Contract.temp_resid_unregistered)
    when "overdue"
      scope.merge(Contract.temp_resid_overdue)
    when "nearly-due", "nearly_due"
      scope.merge(Contract.temp_resid_nearly_due)
    else
      scope
    end
  end

  def filtering_by_contract?
    contract_state.present? && contract_state != "all" ||
      residence_state.present? && residence_state != "all"
  end
end
