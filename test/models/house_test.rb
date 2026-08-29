require "test_helper"

class HouseTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Tran",
      tel: "0901112222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "female",
      bday: 32.years.ago.to_date,
      address: "123 Landlord Ave",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    # House 1: Occupied & available (2 rooms, 1 tenant / 4 slots)
    @house_occupied = House.create!(
      landlord: @landlord,
      name: "House Alpha",
      mode: :room,
      address_l1: "1 Alpha St",
      address_l2: "Ward A",
      address_l3: "District A",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor1 = @house_occupied.floors.create!(name: "Tầng 1", position: 1)
    room1 = floor1.rooms.create!(name: "101", area: 20, max_slots: 2, tenants_count: 1)
    room1.create_rental_unit!(rent: 2_000_000, deposit: 2_000_000)
    room2 = floor1.rooms.create!(name: "102", area: 20, max_slots: 2, tenants_count: 0)
    room2.create_rental_unit!(rent: 2_000_000, deposit: 2_000_000)

    # House 2: Full (1 room, 2 tenants / 2 slots)
    @house_full = House.create!(
      landlord: @landlord,
      name: "House Beta",
      mode: :room,
      address_l1: "2 Beta St",
      address_l2: "Ward B",
      address_l3: "District B",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor2 = @house_full.floors.create!(name: "Tầng 1", position: 1)
    room_f = floor2.rooms.create!(name: "201", area: 20, max_slots: 2, tenants_count: 2)
    room_f.create_rental_unit!(rent: 2_000_000, deposit: 2_000_000)

    # House 3: Completely empty (1 room, 0 tenants / 2 slots)
    @house_empty = House.create!(
      landlord: @landlord,
      name: "House Gamma",
      mode: :room,
      address_l1: "3 Gamma St",
      address_l2: "Ward G",
      address_l3: "District G",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor3 = @house_empty.floors.create!(name: "Tầng 1", position: 1)
    room_e = floor3.rooms.create!(name: "301", area: 20, max_slots: 2, tenants_count: 0)
    room_e.create_rental_unit!(rent: 2_000_000, deposit: 2_000_000)
  end

  test "by_state(:not_empty) filters houses with tenants" do
    result = House.by_state("not_empty")
    assert_includes result, @house_occupied
    assert_includes result, @house_full
    assert_not_includes result, @house_empty
  end

  test "by_state(:available) filters houses with remaining slots" do
    result = House.by_state("available")
    assert_includes result, @house_occupied
    assert_includes result, @house_empty
    assert_not_includes result, @house_full
  end

  test "by_state(:full) filters houses completely filled" do
    result = House.by_state("full")
    assert_includes result, @house_full
    assert_not_includes result, @house_occupied
    assert_not_includes result, @house_empty
  end

  test "by_state(:empty) filters completely empty houses" do
    result = House.by_state("empty")
    assert_includes result, @house_empty
    assert_not_includes result, @house_occupied
    assert_not_includes result, @house_full
  end
end
