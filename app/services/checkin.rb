# Link a tenant to a rental unit
class Checkin
  def self.call(...)
    new(...).call
  end

  def initialize(house:, tenant_id:, rental_unit_id:, send_noti: true)
    @house = house
    @tenant_id = tenant_id
    @rental_unit_id = rental_unit_id
    @send_noti = send_noti
  end

  def call
    tenant_stay = TenantStay.transaction do
      tenant = Tenant.lock.find(tenant_id)
      rental_unit = house.available_rental_units.find(rental_unit_id)

      rental_unit.lock!

      validate_tenant!(tenant)
      validate_rental_unit!(rental_unit)

      # update occupancy
      rental_unit.tenant_added!

      TenantStay.create!(
        tenant: tenant,
        rental_unit: rental_unit,
        checkin_at: Time.current
      )
    end

    send_notification(tenant_stay) if @send_noti

    tenant_stay
  end


  private

  attr_reader :house, :tenant_id, :rental_unit_id

  # Check if a tenant is already linked before
  def validate_tenant!(tenant)
    raise ActiveRecord::RecordInvalid, tenant if tenant.linked?
  end

  # Chek if a rental unit is available
  def validate_rental_unit!(rental_unit)
    raise ActiveRecord::RecordInvalid, rental_unit unless rental_unit.available?
  end

  # Send notification to that tenant
  def send_notification(tenant_stay)
    rental_unit = tenant_stay.rental_unit

    TenantAddedNotifier.with(
      tenant_stay: tenant_stay,
      house: house.name,
      floor: rental_unit.floor.name,
      rental_unit: rental_unit.title_name
    ).deliver_later(tenant_stay.tenant.user)
  end
end
