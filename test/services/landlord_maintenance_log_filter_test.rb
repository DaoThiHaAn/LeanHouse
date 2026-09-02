require "test_helper"

class LandlordMaintenanceLogFilterTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Filter Test",
      tel: "0907778899",
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
      name: "Filter House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
    @asset = @room.assets.create!(
      category: "air_con",
      price: 5_000_000,
      brand: "Daikin",
      model: "FTKQ25",
      purchased_at: 2.years.ago.to_date,
      status: :normal
    )

    # Logs in different months and years
    @log_2025_06 = @asset.maintenance_logs.create!(
      performed_on: Date.new(2025, 6, 10),
      cost: 200_000,
      content: "Bơm gas tháng 6/2025"
    )
    @log_2025_08 = @asset.maintenance_logs.create!(
      performed_on: Date.new(2025, 8, 15),
      cost: 350_000,
      content: "Vệ sinh tháng 8/2025"
    )
    @log_2026_06 = @asset.maintenance_logs.create!(
      performed_on: Date.new(2026, 6, 20),
      cost: 500_000,
      content: "Bảo dưỡng tháng 6/2026"
    )
  end

  test "returns all logs and sum of costs when no filter params are given" do
    result = LandlordMaintenanceLogFilter.call(asset: @asset, params: {})

    assert_equal 3, result[:total_count]
    assert_equal 1_050_000, result[:total_cost]
    assert_equal 3, result[:logs].count
  end

  test "filters by year" do
    result = LandlordMaintenanceLogFilter.call(asset: @asset, params: { year: "2025" })

    assert_equal 2, result[:total_count]
    assert_equal 550_000, result[:total_cost]
    assert_includes result[:logs], @log_2025_06
    assert_includes result[:logs], @log_2025_08
    assert_not_includes result[:logs], @log_2026_06
  end

  test "filters by year and month" do
    result = LandlordMaintenanceLogFilter.call(asset: @asset, params: { year: "2025", month: "6" })

    assert_equal 1, result[:total_count]
    assert_equal 200_000, result[:total_cost]
    assert_includes result[:logs], @log_2025_06
    assert_not_includes result[:logs], @log_2025_08
    assert_not_includes result[:logs], @log_2026_06
  end

  test "filters by month across any year when only month is given" do
    result = LandlordMaintenanceLogFilter.call(asset: @asset, params: { month: "6" })

    assert_equal 2, result[:total_count]
    assert_equal 700_000, result[:total_cost]
    assert_includes result[:logs], @log_2025_06
    assert_includes result[:logs], @log_2026_06
    assert_not_includes result[:logs], @log_2025_08
  end
end
