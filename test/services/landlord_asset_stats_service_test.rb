require "test_helper"

class LandlordAssetStatsServiceTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Asset Test",
      tel: "0908889999",
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
      name: "Asset Test House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
  end

  test "returns all zeros when house has no assets" do
    stats = LandlordAssetStatsService.call(house: @house)

    assert_equal 0, stats[:total_count]
    assert_equal 0, stats[:normal_count]
    assert_equal 0, stats[:damaged_count]
    assert_equal 0, stats[:total_price]
  end

  test "correctly calculates stats with normal, damaged and under_repair assets" do
    @room.assets.create!(category: "fridge", price: 10_000_000, status: :normal)
    @room.assets.create!(category: "air_con", price: 12_000_000, status: :normal)
    @room.assets.create!(category: "tv", price: 8_000_000, status: :damaged)
    @room.assets.create!(category: "wash_mach", price: 5_000_000, status: :under_repair)

    stats = LandlordAssetStatsService.call(house: @house)

    assert_equal 4, stats[:total_count]
    assert_equal 2, stats[:normal_count]
    assert_equal 2, stats[:damaged_count] # 1 damaged + 1 under_repair
    assert_equal 35_000_000, stats[:total_price]
  end
end
