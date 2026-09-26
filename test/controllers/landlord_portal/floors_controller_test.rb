# frozen_string_literal: true

require "test_helper"

class LandlordPortal::FloorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = create_landlord(tel: "0908889911")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Tầng",
      mode: :room,
      address_l1: "Phường 1",
      address_l2: "Quận 1",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 0)

    post "/login", params: {
      user: {
        tel: @landlord_user.tel,
        password: "Password123",
        role: "landlord"
      }
    }
  end

  test "new, create, update, check_delete, and destroy floor" do
    get new_landlord_house_floor_path(@house)
    assert_response :success

    assert_difference -> { @house.floors.count }, 1 do
      post landlord_house_floors_path(@house), params: {
        floor: {
          name: "Tầng 2",
          rooms_count: 1,
          room_area: 20,
          room_capacity: 2,
          room_rent: 3_000_000,
          room_deposit: 3_000_000
        }
      }, as: :turbo_stream
    end
    assert_response :success

    patch landlord_house_floor_path(@house, @floor), params: {
      floor: { name: "Tầng Trệt" }
    }, as: :turbo_stream
    assert_response :success
    assert_equal "Tầng Trệt", @floor.reload.name

    # Invalid update
    patch landlord_house_floor_path(@house, @floor), params: {
      floor: { name: "" }
    }, as: :turbo_stream
    assert_response :unprocessable_entity

    patch sort_landlord_house_floors_path(@house), params: {
      floor_ids: [ @floor.id ]
    }, as: :turbo_stream
    assert_response :success

    delete landlord_house_floor_path(@house, @floor)
    assert_redirected_to edit_landlord_house_path(@house)
  end
end
