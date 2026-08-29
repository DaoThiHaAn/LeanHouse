require "test_helper"

class LandlordPortal::VehiclesControllerTest < ActionDispatch::IntegrationTest
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

    @tenant_user = User.create!(
      fullname: "Tenant Le",
      tel: "0907654321",
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
      name: "Happy House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @vehicle = Vehicle.create!(
      tenant: @tenant,
      house: @house,
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "Vision"
    )
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

  test "landlord can view vehicles index" do
    sign_in_as(@landlord_user)

    get landlord_house_vehicles_path(@house)
    assert_response :success
    assert_select "h1", text: I18n.t("page_titles.vehicle_mng")
    assert_select "turbo-frame#vehicle_table"
    assert_includes response.body, "59A-12345"
  end

  test "landlord can filter vehicles by type" do
    car = Vehicle.create!(
      tenant: @tenant,
      house: @house,
      license_plate: "51K-99999",
      vehicle_type: :car,
      brand: "Toyota"
    )

    sign_in_as(@landlord_user)

    get filtered_landlord_house_vehicles_path(@house, vehicle_type: "car")
    assert_response :success
    assert_includes response.body, "51K-99999"
    assert_not_includes response.body, "59A-12345"
  end

  test "landlord can delete vehicle with reason" do
    sign_in_as(@landlord_user)

    assert_difference -> { Vehicle.count }, -1 do
      delete landlord_house_vehicle_path(@house, @vehicle),
             params: { reason: "Xe không còn để trong hầm" },
             as: :turbo_stream
    end

    assert_response :success
  end

  test "landlord cannot delete vehicle without reason" do
    sign_in_as(@landlord_user)

    assert_no_difference -> { Vehicle.count } do
      delete landlord_house_vehicle_path(@house, @vehicle),
             params: { reason: "" },
             as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test "shows empty card when house has no vehicles at all" do
    empty_house = House.create!(
      landlord: @landlord,
      name: "Empty House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    sign_in_as(@landlord_user)
    get landlord_house_vehicles_path(empty_house)

    assert_response :success
    assert_select "p", text: I18n.t("vehicle.no_vehicles")
    assert_select "table", 0
  end

  test "shows unfound message in table row when filter yields no results" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_vehicles_path(@house, query: "NON_EXISTING_QUERY_12345")
    assert_response :success
    assert_select "table"
    assert_select "tbody tr td", text: I18n.t("vehicle.no_vehicles_found")
  end
end
