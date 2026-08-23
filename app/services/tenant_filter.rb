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
      .preload(:user, :contracts, tenant_stays: { rental_unit: :rentable })
      .order("users.fullname ASC")
      .page(page)
      .per(TENANTS_PER_PAGE)
  end

  private

  attr_reader :house, :query, :contract_state, :residence_state, :page

  # Base scope: Lấy danh sách ID khách thuê đang lưu trú có hợp đồng qua Subquery (không bị nhân đôi bản ghi)
  def base_scope
    rentable_records = house.room? ? house.rooms : house.beds
    rental_units = RentalUnit.where(rentable: rentable_records)

    active_tenant_ids = TenantStay
      .staying
      .where(rental_unit_id: rental_units, has_contract: true)
      .select(:tenant_id)

    Tenant.joins(:user).where(id: active_tenant_ids)
  end

  def apply_search(scope)
    return scope if query.blank?

    scope.search(query)
  end

  # Lọc hợp đồng theo subquery
  def apply_contract_filters(scope)
    return scope unless filtering_by_contract?

    contract_scope = Contract.where(house_id: house.id)
    contract_scope = apply_contract_state(contract_scope)
    contract_scope = apply_residence_state(contract_scope)

    scope.where(id: contract_scope.select(:tenant_id))
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
