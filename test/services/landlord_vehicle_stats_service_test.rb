require "test_helper"

class LandlordVehicleStatsServiceTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Vehicle Test",
      tel: "0906665544",
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
      fullname: "Tenant Vehicle Test",
      tel: "0905554433",
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
      name: "Vehicle Stats House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
  end

  test "returns 0 total and 0 for each type when house has no vehicles" do
    stats = LandlordVehicleStatsService.call(house: @house)

    assert_equal 0, stats[:total_count]
    assert_equal 0, stats[:type_counts]["motorbike"]
    assert_equal 0, stats[:type_counts]["electric_bike"]
    assert_equal 0, stats[:type_counts]["bicycle"]
    assert_equal 0, stats[:type_counts]["car"]
  end

  test "correctly aggregates counts for each vehicle type in the house" do
    @house.vehicles.create!(tenant: @tenant, license_plate: "59A-11111", vehicle_type: :motorbike)
    @house.vehicles.create!(tenant: @tenant, license_plate: "59A-22222", vehicle_type: :motorbike)
    @house.vehicles.create!(tenant: @tenant, license_plate: "59A-33333", vehicle_type: :electric_bike)
    @house.vehicles.create!(tenant: @tenant, license_plate: "59A-44444", vehicle_type: :bicycle)

    # Another house vehicle to test house scoping
    other_house = House.create!(
      landlord: @landlord,
      name: "Other House",
      mode: :room,
      address_l1: "456 Other St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    other_house.vehicles.create!(tenant: @tenant, license_plate: "59B-99999", vehicle_type: :car)

    stats = LandlordVehicleStatsService.call(house: @house)

    assert_equal 4, stats[:total_count]
    assert_equal 2, stats[:type_counts]["motorbike"]
    assert_equal 1, stats[:type_counts]["electric_bike"]
    assert_equal 1, stats[:type_counts]["bicycle"]
    assert_equal 0, stats[:type_counts]["car"]
  end
end
