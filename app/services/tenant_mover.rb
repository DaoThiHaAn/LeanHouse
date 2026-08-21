# Move a linked tenant to another rental unit
class TenantMover
  def self.call(...)
    new(...).call
  end

  def initialize(house:, tenant_stay:, rental_unit_id:, send_noti: true)
    @house = house
    @tenant_stay = tenant_stay
    @rental_unit_id = rental_unit_id
    @send_noti = send_noti
  end

  def call
    validate_different_rental_unit!

    new_tenant_stay = TenantStay.transaction do
      # 1. Checkout old rental unit and decrease old occupancy
      tenant_stay.update!(checkout_at: Time.current)
      tenant_stay.rental_unit.tenant_removed!

      # 2. Acquire and validate new rental unit
      new_rental_unit = house.available_rental_units.find(rental_unit_id)
      new_rental_unit.lock!
      validate_rental_unit!(new_rental_unit)

      # 3. Increase new unit occupancy and create new stay
      new_rental_unit.tenant_added!

      TenantStay.create!(
        tenant: tenant_stay.tenant,
        rental_unit: new_rental_unit,
        checkin_at: Time.current,
        has_contract: tenant_stay.has_contract
      )
    end

    send_notification(new_tenant_stay) if @send_noti

    new_tenant_stay
  end

  private

  attr_reader :house, :tenant_stay, :rental_unit_id

  def validate_different_rental_unit!
    if tenant_stay.rental_unit_id == rental_unit_id.to_i
      raise ActiveRecord::RecordInvalid, tenant_stay
    end
  end

  def validate_rental_unit!(rental_unit)
    raise ActiveRecord::RecordInvalid, rental_unit unless rental_unit.available?
  end

  def send_notification(new_tenant_stay)
    rental_unit = new_tenant_stay.rental_unit

    TenantMovedNotifier.with(
      tenant_stay: new_tenant_stay,
      house: house.name,
      floor: rental_unit.floor.name,
      rental_unit: rental_unit.title_name
    ).deliver_later(new_tenant_stay.tenant.user)
  end
end
