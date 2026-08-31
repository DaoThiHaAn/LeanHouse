require "test_helper"

class LandlordPortal::RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
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

  test "updates empty room capacity successfully (increase and decrease)" do
    sign_in_as(@landlord_user)

    patch landlord_house_room_path(@house, @room_empty), params: {
      room: {
        name: "Gamma Updated",
        floor_id: @floor.id,
        area: 30,
        max_slots: 1,
        rent: 3_500_000,
        deposit: 3_500_000
      }
    }

    assert_redirected_to landlord_house_rooms_path(@house)
    @room_empty.reload
    assert_equal "Gamma Updated", @room_empty.name
    assert_equal 1, @room_empty.max_slots
    assert_equal 30, @room_empty.area
  end

  test "updates room with turbo_stream replacing row in place and closing modal" do
    sign_in_as(@landlord_user)

    patch landlord_house_room_path(@house, @room_empty), params: {
      room: {
        name: "Gamma Stream Updated",
        floor_id: @floor.id,
        area: 32,
        max_slots: 1,
        rent: 3_800_000,
        deposit: 3_800_000
      }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_includes response.body, %(action="replace" target="room_#{@room_empty.id}")
    assert_includes response.body, "Gamma Stream Updated"
    assert_includes response.body, %(action="append" target="events")
    assert_includes response.body, "close-modal"
    assert_includes response.body, %(action="update" target="flash")

    @room_empty.reload
    assert_equal "Gamma Stream Updated", @room_empty.name
    assert_equal 1, @room_empty.max_slots
    assert_equal 32, @room_empty.area
  end

  test "updates occupied room capacity down to tenants_count successfully" do
    sign_in_as(@landlord_user)

    # @room_occupied has max_slots: 2, tenants_count: 1 -> reducing to 1 should succeed
    patch landlord_house_room_path(@house, @room_occupied), params: {
      room: {
        name: "Alpha",
        floor_id: @floor.id,
        area: 25,
        max_slots: 1,
        rent: 3_000_000,
        deposit: 3_000_000
      }
    }

    assert_redirected_to landlord_house_rooms_path(@house)
    @room_occupied.reload
    assert_equal 1, @room_occupied.max_slots
  end

  test "fails to reduce occupied room capacity below tenants_count" do
    sign_in_as(@landlord_user)

    # @room_full has max_slots: 2, tenants_count: 2 -> reducing to 1 should fail
    patch landlord_house_room_path(@house, @room_full), params: {
      room: {
        name: "Beta",
        floor_id: @floor.id,
        area: 25,
        max_slots: 1,
        rent: 3_000_000,
        deposit: 3_000_000
      }
    }

    assert_response :unprocessable_entity
    @room_full.reload
    assert_equal 2, @room_full.max_slots
  end

  test "updates room attributes in bed mode without altering bed counter cache" do
    bed_house = House.create!(
      landlord: @landlord,
      name: "Dorm House",
      mode: :bed,
      address_l1: "456 Dorm St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    bed_floor = bed_house.floors.create!(name: "Tầng 1", position: 1)
    bed_room = bed_floor.rooms.create!(name: "Room 101", area: 30, max_slots: 0, tenants_count: 0)
    bed_room.create_beds(count: 3, rent: 1_500_000, deposit: 1_500_000)
    bed_room.reload
    assert_equal 3, bed_room.max_slots

    sign_in_as(@landlord_user)

    patch landlord_house_room_path(bed_house, bed_room), params: {
      room: {
        name: "Room 101 Renovated",
        floor_id: bed_floor.id,
        area: 35,
        max_slots: 10, # Bed mode ignores max_slots from room edit
        rent: 1_600_000,
        deposit: 1_600_000
      }
    }

    assert_redirected_to landlord_house_rooms_path(bed_house)
    bed_room.reload
    assert_equal "Room 101 Renovated", bed_room.name
    assert_equal 35, bed_room.area
    assert_equal 3, bed_room.max_slots # preserved counter cache
  end

  test "syncs services during room edit (adding, switching variant, and removing)" do
    service = @house.services.create!(name: "Electricity")
    variant1 = service.service_variants.create!(fee: 3_500, unit: :per_kwh, is_real_time: true)
    variant2 = service.service_variants.create!(fee: 4_000, unit: :per_kwh, is_real_time: true)

    service_wifi = @house.services.create!(name: "Wifi")
    variant_wifi = service_wifi.service_variants.create!(fee: 100_000, unit: :per_month, is_real_time: false)

    sign_in_as(@landlord_user)

    # 1. Apply variant1 and wifi
    patch landlord_house_room_path(@house, @room_empty), params: {
      room: {
        name: "Gamma",
        floor_id: @floor.id,
        area: 25,
        max_slots: 2,
        rent: 3_000_000,
        deposit: 3_000_000,
        service_selections: {
          service.id.to_s => { selected: "1", variant_id: variant1.id.to_s },
          service_wifi.id.to_s => { selected: "1", variant_id: variant_wifi.id.to_s }
        }
      }
    }

    assert_redirected_to landlord_house_rooms_path(@house)
    @room_empty.reload
    assert_equal 2, @room_empty.room_services.count
    assert_includes @room_empty.service_variants, variant1
    assert_includes @room_empty.service_variants, variant_wifi

    # 2. Switch electricity from variant1 to variant2 and uncheck wifi
    patch landlord_house_room_path(@house, @room_empty), params: {
      room: {
        name: "Gamma",
        floor_id: @floor.id,
        area: 25,
        max_slots: 2,
        rent: 3_000_000,
        deposit: 3_000_000,
        service_selections: {
          service.id.to_s => { selected: "1", variant_id: variant2.id.to_s },
          service_wifi.id.to_s => { selected: "0", variant_id: "" }
        }
      }
    }

    assert_redirected_to landlord_house_rooms_path(@house)
    @room_empty.reload
    assert_equal 1, @room_empty.room_services.count
    assert_includes @room_empty.service_variants, variant2
    assert_not_includes @room_empty.service_variants, variant1
    assert_not_includes @room_empty.service_variants, variant_wifi
  end
end
