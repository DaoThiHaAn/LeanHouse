require "test_helper"

class LandlordPortal::RoomsControllerTest < ActionDispatch::IntegrationTest
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

    @house = House.create!(
      landlord: @landlord,
      name: "Happy House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)

    # Room 1: Occupied/Not empty (tenants_count: 1, max_slots: 2)
    @room_occupied = @floor.rooms.create!(
      name: "Alpha",
      area: 25,
      max_slots: 2,
      tenants_count: 1
    )
    @room_occupied.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    # Room 2: Full (tenants_count: 2, max_slots: 2)
    @room_full = @floor.rooms.create!(
      name: "Beta",
      area: 25,
      max_slots: 2,
      tenants_count: 2
    )
    @room_full.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    # Room 3: Empty (tenants_count: 0, max_slots: 2)
    @room_empty = @floor.rooms.create!(
      name: "Gamma",
      area: 25,
      max_slots: 2,
      tenants_count: 0
    )
    @room_empty.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "filters rooms by state not_empty" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_rooms_path(@house, state: "not_empty")
    assert_response :success
    assert_includes response.body, "Phòng Alpha"
    assert_includes response.body, "Phòng Beta"
    assert_not_includes response.body, "Phòng Gamma"
  end

  test "filters rooms by state empty" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_rooms_path(@house, state: "empty")
    assert_response :success
    assert_includes response.body, "Phòng Gamma"
    assert_not_includes response.body, "Phòng Alpha"
    assert_not_includes response.body, "Phòng Beta"
  end

  test "filters rooms by state available" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_rooms_path(@house, state: "available")
    assert_response :success
    # Available has tenants_count < max_slots -> Alpha (1/2) and Gamma (0/2)
    assert_includes response.body, "Phòng Alpha"
    assert_includes response.body, "Phòng Gamma"
    assert_not_includes response.body, "Phòng Beta"
  end

  test "filters rooms by state full" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_rooms_path(@house, state: "full")
    assert_response :success
    assert_includes response.body, "Phòng Beta"
    assert_not_includes response.body, "Phòng Alpha"
    assert_not_includes response.body, "Phòng Gamma"
  end
end
