require "test_helper"

class FloorTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901235566")
    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Floor Test House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 0)
  end

  test "floor requires unique name within the same house" do
    duplicate_floor = @house.floors.build(name: "Tầng 1", position: 2)
    assert_not duplicate_floor.valid?
    assert duplicate_floor.errors[:name].present?
  end

  test "title_name formats properly" do
    assert_includes @floor.title_name, "Tầng 1"
  end

  test "generate_rooms creates specified number of rooms and rental units" do
    assert_difference -> { @floor.rooms.count }, 3 do
      @floor.generate_rooms!(
        mode: :room,
        count: 3,
        max_slots: 2,
        rent: 2_000_000,
        deposit: 2_000_000,
        area: 20.0
      )
    end

    assert_equal 6, @floor.total_slots
    assert @floor.can_delete?
  end
end
