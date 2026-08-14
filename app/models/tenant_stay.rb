class TenantStay < ApplicationRecord
  belongs_to :tenant, inverse_of: :tenant_stays
  belongs_to :rental_unit, inverse_of: :tenant_stays

  validates :checkout_at, comparison: { greater_than_or_equal_to: :checkin_at }, allow_nil: true

  scope :staying, -> { where(checkout_at: nil) }

  # MODEL METHODS

  # Create an active stay for a tenant and an available unit in the given house.
  def self.link!(house:, tenant_id:, rental_unit_id:)
    tenant_stay = transaction do
      # Prevent race condition
      tenant = Tenant.lock.find(tenant_id)
      rental_unit = house.available_rental_units.find(rental_unit_id)
      rental_unit.lock!

      raise ActiveRecord::RecordInvalid, tenant if tenant.linked?
      raise ActiveRecord::RecordInvalid, rental_unit if rental_unit.tenant_stays.exists?(check_out: nil)

      # Update tenants_count in Room or "is_available" in Bed
      rental_unit.rentable.with_lock do
        room = rental_unit.rentable.is_a?(Bed) ? rental_unit.rentable.room : rental_unit.rentable
        room.increment!(:tenants_count)
        rental_unit.rentable.update!(is_available: false) if rental_unit.rentable.is_a?(Bed)
      end

      create!(tenant: tenant, rental_unit: rental_unit, checkin_at: Time.current)
    end

    # Send notification
    rentable = tenant_stay.rental_unit.rentable
    room = rentable.is_a?(Bed) ? rentable.room : rentable

    TenantAddedNotifier.with(
      tenant_stay: tenant_stay,
      house: house.name,
      floor: room.floor.name,
      rental_unit: rentable.name
    ).deliver_later(tenant_stay.tenant.user)

    tenant_stay
  end
end
