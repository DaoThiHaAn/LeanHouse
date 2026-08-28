require "test_helper"

class TenantPortal::VehiclesControllerTest < ActionDispatch::IntegrationTest
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

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: Date.current
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

  test "linked tenant can view their vehicles" do
    sign_in_as(@tenant_user)

    get tenant_vehicles_path
    assert_response :success
    assert_includes response.body, "59A-12345"
    assert_includes response.body, "Honda"
  end

  test "tenant can delete their vehicle with reason" do
    sign_in_as(@tenant_user)

    assert_difference -> { Vehicle.count }, -1 do
      delete tenant_vehicle_path(@vehicle),
             params: { reason: "Tôi đã bán xe" },
             as: :turbo_stream
    end

    assert_response :success
    assert_not Vehicle.exists?(@vehicle.id)
  end

  test "tenant cannot delete vehicle without reason" do
    sign_in_as(@tenant_user)

    assert_no_difference -> { Vehicle.count } do
      delete tenant_vehicle_path(@vehicle),
             params: { reason: "" },
             as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end
end
