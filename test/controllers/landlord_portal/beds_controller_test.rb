require "test_helper"

class LandlordPortal::BedsControllerTest < ActionDispatch::IntegrationTest
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
      name: "Happy Dorm",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(
      name: "Room 101",
      area: 30,
      max_slots: 0,
      tenants_count: 0
    )
    @room.create_beds(count: 2, rent: 1_200_000, deposit: 1_200_000)
    @room.reload
    @bed1 = @room.beds.first
    @bed2 = @room.beds.second
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

  test "GET edit renders edit bed modal" do
    sign_in_as(@landlord_user)

    get edit_landlord_house_bed_path(@house, @bed1), headers: { "Turbo-Frame" => "edit_bed_modal" }
    assert_response :success
    assert_includes response.body, "editBedModal"
    assert_includes response.body, @bed1.name
    assert_includes response.body, "1200000"
  end

  test "PATCH update with turbo_stream updates bed attributes and replaces row in place" do
    sign_in_as(@landlord_user)

    patch landlord_house_bed_path(@house, @bed1), params: {
      bed: {
        name: "Bed A Premium",
        rent: "1,500,000",
        deposit: "1,500,000"
      }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_includes response.body, %(action="replace" target="bed_#{@bed1.id}")
    assert_includes response.body, "Bed A Premium"
    assert_includes response.body, "1,500,000"
    assert_includes response.body, %(action="append" target="events")
    assert_includes response.body, "close-modal"
    assert_includes response.body, %(action="update" target="flash")

    @bed1.reload
    assert_equal "Bed A Premium", @bed1.name
    assert_equal 1_500_000, @bed1.rental_unit.rent
    assert_equal 1_500_000, @bed1.rental_unit.deposit
  end

  test "PATCH update with HTML redirects to rooms path with notice" do
    sign_in_as(@landlord_user)

    patch landlord_house_bed_path(@house, @bed1), params: {
      bed: {
        name: "Bed A HTML",
        rent: 1_600_000,
        deposit: 1_600_000
      }
    }

    assert_redirected_to landlord_house_rooms_path(@house)
    @bed1.reload
    assert_equal "Bed A HTML", @bed1.name
    assert_equal 1_600_000, @bed1.rental_unit.rent
  end

  test "PATCH update with invalid parameters returns 422 unprocessable_entity" do
    sign_in_as(@landlord_user)

    patch landlord_house_bed_path(@house, @bed1), params: {
      bed: {
        name: "", # Blank name
        rent: 1_500_000,
        deposit: 1_500_000
      }
    }, as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, "editBedModal"
    @bed1.reload
    assert_not_equal "", @bed1.name
  end

  test "redirects when house is not in bed mode" do
    room_house = House.create!(
      landlord: @landlord,
      name: "Apartment House",
      mode: :room,
      address_l1: "456 Apt St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )

    sign_in_as(@landlord_user)
    get edit_landlord_house_bed_path(room_house, @bed1)
    assert_redirected_to landlord_house_rooms_path(room_house)
  end
end
