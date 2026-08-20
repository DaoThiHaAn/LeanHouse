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
    end

    send_notification(tenant_stay) if @send_noti
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

  # TODO
  def end_contract!
    return unless tenant_stay.has_contract?

    tenant_stay.contract.update!(
      end_date: Time.current.to_date
    )
  end

  def send_notification
    rental_unit = tenant_stay.rental_unit

    TenantRemovedNotifier.with(
      tenant_stay: tenant_stay,
      house: house.name,
      floor: rental_unit.floor.name,
      rental_unit: rental_unit.title_name
    ).deliver_later(tenant_stay.tenant.user)
  end
end
