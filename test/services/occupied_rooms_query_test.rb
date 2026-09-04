require "test_helper"

class OccupiedRoomsQueryTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Query Test",
      tel: "0901239999",
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
      fullname: "Tenant Query Stayer",
      tel: "0907659999",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Tenant Rd",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Occupied Query House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 2,
      inv_creation_date: 1
    )

    @floor1 = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @floor2 = @house.floors.create!(name: "Tầng 2", position: 2, rooms_count: 1)
    @occupied_room = @floor1.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 20.0)
    @vacant_room = @floor2.rooms.create!(name: "201", max_slots: 2, tenants_count: 0, area: 22.0)

    unit = @occupied_room.create_rental_unit!(rent: 2_500_000, deposit: 2_500_000)
    unit.tenant_stays.create!(tenant: @tenant, checkin_at: 1.month.ago, checkout_at: nil)
  end

  test "returns only occupied rooms and their corresponding floors" do
    result = Invoices::OccupiedRoomsQuery.call(@house)

    assert_includes result[:occupied_rooms], @occupied_room
    assert_not_includes result[:occupied_rooms], @vacant_room

    assert_includes result[:floors], @floor1
    assert_not_includes result[:floors], @floor2

    room_data = result[:rooms_data].find { |r| r[:id] == @occupied_room.id }
    assert_not_nil room_data
    assert_equal @occupied_room.title_name, room_data[:name]
    assert_equal @floor1.id, room_data[:floor_id]
    assert_equal 1, room_data[:tenants_count]
    assert_equal 1, room_data[:tenants].size
    assert_equal @tenant.id, room_data[:tenants].first[:id]
    assert_equal @tenant_user.fullname, room_data[:tenants].first[:name]
  end

  test "in bed mode includes bed name in tenant label" do
    bed_house = House.create!(
      landlord: @landlord,
      name: "Bed Mode House",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = bed_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 20.0)
    bed = room.beds.create!(name: "A1")
    bed_unit = bed.create_rental_unit!(rent: 1_200_000, deposit: 1_200_000)
    bed_user = User.create!(
      fullname: "Bed Tenant Tester",
      tel: "0909998888",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 21.years.ago.to_date,
      address: "Bed St",
      tel_verified_at: Time.current
    )
    bed_tenant = Tenant.find_or_create_by!(id: bed_user.id)
    bed_unit.tenant_stays.create!(tenant: bed_tenant, checkin_at: 1.month.ago, checkout_at: nil)

    result = Invoices::OccupiedRoomsQuery.call(bed_house)
    room_data = result[:rooms_data].find { |r| r[:id] == room.id }
    assert_not_nil room_data
    assert_equal 1, room_data[:tenants].size
    tenant_info = room_data[:tenants].first
    assert_includes tenant_info[:name], "Bed Tenant Tester"
    assert_includes tenant_info[:name], "A1"
  end
end
