class ContractClosing
  def self.call(...)
    new(...).call
  end

  def initialize(house:, contract:, remove_tenant: false)
    @house = house
    @contract = contract
    @remove_tenant = remove_tenant
  end

  def call
    tenant_stay = house.tenant_stay_for(contract.tenant_id)

    Contract.transaction do
      # 1. Close contract (soft completion by setting end_date)
      contract.update!(end_date: Date.current)

      tenant_stay&.update!(has_contract: false)

      # 2. If remove_tenant is checked, checkout the tenant stay
      if @remove_tenant && tenant_stay
        tenant_stay.update!(checkout_at: Time.current)
        tenant_stay.rental_unit.tenant_removed! # Decrements room.tenants_count, frees up bed
      end
    end

    # 3. Send contract closed notifications to Landlord and Tenant
    send_contract_closed_notifications

    # 4. If tenant was also removed from the house, send tenant removed notifications to Landlord and Tenant
    if @remove_tenant && tenant_stay
      send_tenant_removed_notifications(tenant_stay)
    end

    contract
  end

  private

  attr_reader :house, :contract

  def send_contract_closed_notifications
    recipients = [ contract.tenant.user, contract.landlord.user ].compact.uniq

    ContractClosedNotifier.with(
      contract: contract,
      contract_id: contract.id,
      contract_name: contract.name,
      tenant_name: contract.tenant.user.fullname,
      house_id: house.id
    ).deliver_later(recipients)
  end

  def send_tenant_removed_notifications(tenant_stay)
    rental_unit = tenant_stay.rental_unit
    recipients = [ tenant_stay.tenant.user, house.landlord.user ].compact.uniq

    TenantRemovedNotifier.with(
      tenant_stay: tenant_stay,
      house_id: house.id,
      house: house.name,
      floor: rental_unit.floor.name,
      rental_unit: rental_unit.title_name,
      tenant_name: tenant_stay.tenant.user.fullname
    ).deliver_later(recipients)
  end
end
