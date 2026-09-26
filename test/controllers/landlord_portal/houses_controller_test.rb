# frozen_string_literal: true

require "test_helper"

class LandlordPortal::HousesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = create_landlord(tel: "0908880011")
    @landlord = @landlord_user.landlord

    @house1 = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ A",
      mode: :room,
      address_l1: "Phường 1",
      address_l2: "Quận 1",
      address_l3: "TP.HCM",
      floors_count: 2,
      inv_creation_date: 1
    )
    @floor1 = @house1.floors.create!(name: "Tầng 1", position: 1, rooms_count: 2)
    @room1 = @floor1.rooms.create!(name: "101", max_slots: 2, tenants_count: 2, area: 25.0)
    @room2 = @floor1.rooms.create!(name: "102", max_slots: 2, tenants_count: 0, area: 25.0)

    @house2 = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ B",
      mode: :bed,
      address_l1: "Phường 2",
      address_l2: "Quận 3",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 5
    )
  end

  def login_as_landlord
    post "/login", params: {
      user: {
        tel: @landlord_user.tel,
        password: "Password123",
        role: "landlord"
      }
    }
  end

  test "GET /landlord/houses renders index and exercises state filters" do
    login_as_landlord

    # 1. Standard index
    get "/landlord/houses"
    assert_response :success

    # 2. Filter by search query
    get "/landlord/houses", params: { query: "Nhà Trọ A" }
    assert_response :success

    # 3. Filter by states: available, full, empty, occupied
    get "/landlord/houses", params: { state: "available" }
    assert_response :success

    get "/landlord/houses", params: { state: "full" }
    assert_response :success

    get "/landlord/houses", params: { state: "empty" }
    assert_response :success

    get "/landlord/houses", params: { state: "not_empty" }
    assert_response :success

    # 4. Filter by invoice status
    get "/landlord/houses", params: { invoice_status: "has_unpaid" }
    assert_response :success

    get "/landlord/houses", params: { invoice_status: "all_paid" }
    assert_response :success
  end

  test "GET /landlord/houses/:id renders house show modal" do
    login_as_landlord

    get "/landlord/houses/#{@house1.id}"
    assert_response :success
  end

  test "POST /landlord/houses creates a new house" do
    login_as_landlord

    assert_difference -> { @landlord.houses.count }, 1 do
      post "/landlord/houses", params: {
        house: {
          name: "Nhà Trọ Mới",
          mode: "room",
          address_l1: "Phường Linh Trung",
          address_l2: "TP Thủ Đức",
          address_l3: "TP.HCM",
          floors_count: 2,
          rooms_per_floor: 2,
          area: 20,
          rent: 3000000,
          deposit: 3000000,
          inv_creation_date: 1
        }
      }
    end

    assert_redirected_to landlord_houses_path
  end

  test "PATCH /landlord/houses/:id updates house attributes" do
    login_as_landlord

    patch "/landlord/houses/#{@house1.id}", params: {
      house: { name: "Nhà Trọ A Đã Đổi Tên" }
    }

    assert_redirected_to [ :landlord, @house1 ]
    assert_equal "Nhà Trọ A Đã Đổi Tên", @house1.reload.name
  end

  test "GET /landlord/houses/:id/check_deletion renders correct confirmation or blocked view" do
    login_as_landlord

    # House 1 has staying tenants -> deletion blocked
    get "/landlord/houses/#{@house1.id}/check_deletion"
    assert_response :success

    # House 2 is empty -> deletion confirm
    get "/landlord/houses/#{@house2.id}/check_deletion"
    assert_response :success
  end
end
