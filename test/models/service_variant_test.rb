require "test_helper"

class ServiceVariantTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord User",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "M",
      bday: 30.years.ago.to_date,
      address: "123 Street",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "Test House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room1 = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 20.0)
    @room2 = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 0, area: 20.0)
    @room3 = @floor.rooms.create!(name: "103", max_slots: 2, tenants_count: 0, area: 20.0)

    @service = @house.services.create!(name: "Điện")
    @variant1 = @service.service_variants.create!(fee: 3500, unit: :per_kwh, is_real_time: true)
    @variant2 = @service.service_variants.create!(fee: 100000, unit: :per_person, is_real_time: false)

    # Assign room1 to variant1
    @room1.room_services.create!(service_variant: @variant1)
  end

  test "eligible_rooms excludes rooms assigned to sibling variants of same service" do
    # For variant1, eligible rooms are room1, room2, room3 (since room1 is assigned to variant1, and room2/3 are free)
    assert_includes @variant1.eligible_rooms, @room1
    assert_includes @variant1.eligible_rooms, @room2
    assert_includes @variant1.eligible_rooms, @room3

    # For variant2, room1 is assigned to sibling variant1, so it should be EXCLUDED
    refute_includes @variant2.eligible_rooms, @room1
    assert_includes @variant2.eligible_rooms, @room2
    assert_includes @variant2.eligible_rooms, @room3
  end

  test "sync_room_assignments adds and removes room services accurately" do
    # Assign room2 to variant2
    affected = @variant2.sync_room_assignments([ @room2.id ])
    assert_includes affected, @room2.id
    assert_equal [ @room2 ], @variant2.rooms.reload.to_a

    # Now reassign variant2 to room3 (removing room2)
    affected = @variant2.sync_room_assignments([ @room3.id ])
    assert_includes affected, @room2.id
    assert_includes affected, @room3.id
    assert_equal [ @room3 ], @variant2.rooms.reload.to_a
  end

  test "active_staying_tenant_users returns tenants currently staying in rooms" do
    tenant_user = User.create!(
      fullname: "Tenant An",
      tel: "091#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "F",
      bday: 22.years.ago.to_date,
      address: "Tenant Addr",
      tel_verified_at: Time.current
    )
    tenant = Tenant.find_or_create_by!(id: tenant_user.id)
    rental_unit = @room1.create_rental_unit!(rent: 3000000, deposit: 3000000)
    tenant.tenant_stays.create!(rental_unit: rental_unit, checkin_at: 1.month.ago, checkout_at: nil)

    assert_includes @variant1.active_staying_tenant_users, tenant_user
    assert_empty @variant2.active_staying_tenant_users
  end
end
