require "test_helper"

class VehicleTest < ActiveSupport::TestCase
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

  test "valid vehicle" do
    assert @vehicle.valid?
    assert_equal "Xe máy", @vehicle.human_type
    assert_equal "two_wheeler", @vehicle.type_icon
  end

  test "enforces plate uniqueness scoped to house" do
    dup_vehicle = Vehicle.new(
      tenant: @tenant,
      house: @house,
      license_plate: "59A-12345",
      vehicle_type: :electric_bike
    )
    assert_not dup_vehicle.valid?
    assert dup_vehicle.errors[:license_plate].any?
  end

  test "scopes filter by type and search" do
    car = Vehicle.create!(
      tenant: @tenant,
      house: @house,
      license_plate: "51K-99999",
      vehicle_type: :car,
      brand: "Toyota",
      model: "Vios"
    )

    assert_includes Vehicle.by_type("car"), car
    assert_not_includes Vehicle.by_type("car"), @vehicle

    assert_includes Vehicle.search("Toyota"), car
    assert_includes Vehicle.search("59A"), @vehicle
  end
end
