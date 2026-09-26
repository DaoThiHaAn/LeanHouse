require "test_helper"

class RoomTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901237788")
    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Room Test House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25.0)
  end

  test "room requires unique name within the same floor" do
    duplicate_room = @floor.rooms.build(name: "101", max_slots: 2, tenants_count: 0, area: 20.0)
    assert_not duplicate_room.valid?
    assert duplicate_room.errors[:name].present?
  end

  test "tenants_count cannot exceed max_slots" do
    @room.tenants_count = 3 # max_slots is 2
    assert_not @room.valid?
    assert @room.errors[:tenants_count].present?
  end

  test "title_name formats properly" do
    assert_includes @room.title_name, "101"
  end
end
