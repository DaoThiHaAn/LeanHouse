require "test_helper"

class BedCreationFormTest < ActiveSupport::TestCase
  test "rejects bed counts that exceed the remaining room capacity" do
    user = User.create!(
      fullname: "Owner One",
      tel: "0900000001",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "District 1",
      password: "Password1",
      password_confirmation: "Password1",
      role: "landlord"
    )
    landlord = Landlord.create!(id: user.id, houses_count: 0)
    house = House.create!(
      landlord: landlord,
      name: "Sunset House",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "District 1",
      address_l3: "Ho Chi Minh City",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 1", max_slots: 3, tenants_count: 0, area: 20.0)
    room.create_beds(count: 3, start_at: 0)

    form = BedCreationForm.new(beds_count: 18, floor_id: floor.id, room_id: room.id)
    form.room = room

    assert_not form.valid?
    assert form.errors[:beds_count].present?
  end

  test "creates the next numbered bed names from the current room count" do
    user = User.create!(
      fullname: "Owner Two",
      tel: "0900000002",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "District 2",
      password: "Password1",
      password_confirmation: "Password1",
      role: "landlord"
    )
    landlord = Landlord.create!(id: user.id, houses_count: 0)
    house = House.create!(
      landlord: landlord,
      name: "Sunset House",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "District 1",
      address_l3: "Ho Chi Minh City",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 1", max_slots: 0, tenants_count: 0, area: 20.0)

    room.create_beds(count: 3, start_at: 2)

    assert_equal [ "3", "4", "5" ], room.beds.order(:name).map(&:name)
  end
end
