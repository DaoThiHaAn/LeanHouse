require "test_helper"

class TenantTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Le",
      tel: "0907654321",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Tenant Rd",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house_a = House.create!(
      landlord: @landlord,
      name: "House A",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @house_b = House.create!(
      landlord: @landlord,
      name: "House B",
      mode: :room,
      address_l1: "456 Side St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor_a = @house_a.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room_a = @floor_a.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit_a = @room_a.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @stay_a = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit_a,
      checkin_at: Date.current
    )
  end

  test "linked_houses returns all houses associated with tenant stays" do
    assert_equal [ @house_a ], @tenant.linked_houses.to_a

    # Add stay in house B
    floor_b = @house_b.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room_b = floor_b.rooms.create!(name: "Room 201", max_slots: 2, tenants_count: 1, area: 25.0)
    rental_unit_b = room_b.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)
    TenantStay.create!(
      tenant: @tenant,
      rental_unit: rental_unit_b,
      checkin_at: 1.year.ago,
      checkout_at: 6.months.ago
    )

    assert_equal [ @house_a, @house_b ].sort_by(&:name), @tenant.linked_houses.to_a
  end
end
