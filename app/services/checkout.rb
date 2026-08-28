# Remove a tenant from a rental unit
class Checkout
  def self.call(...)
    new(...).call
  end

  def initialize(house:, tenant_stay:, end_contract: true, send_noti: true)
    @house = house
    @tenant_stay = tenant_stay
    @end_contract = end_contract
    @send_noti = send_noti
  end

  def call
    TenantStay.transaction do
      checkout_stay!
      tenant_stay.rental_unit.tenant_removed!  # Update occupancy
      end_contract! if @end_contract
      remove_vehicles!
    end

    send_notification if @send_noti
    tenant_stay
  end

  private

  attr_reader :tenant_stay, :house

  # Update the checkout time
  def checkout_stay!
    tenant_stay.update!(
      checkout_at: Time.current
    )
  end

  def end_contract!
    contract = house.contracts.unfinished.find_by(tenant_id: tenant_stay.tenant_id)
    if contract
      contract.update!(end_date: Date.current)
      tenant_stay.update!(has_contract: false)
    end
  end

  def remove_vehicles!
    house.vehicles.where(tenant_id: tenant_stay.tenant_id).destroy_all
  end

  def send_notification
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
