require "test_helper"

class AssetTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901119900")
    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Asset Test House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 1, tenants_count: 0, area: 20.0)

    @asset = @room.assets.create!(
      category: "air_conditioner",
      price: 8_000_000,
      brand: "Daikin",
      status: "normal"
    )
  end

  test "asset requires category and price" do
    asset = Asset.new
    assert_not asset.valid?
    assert asset.errors[:category].present?
    assert asset.errors[:price].present?
  end

  test "maintenance logs cascade deletion with asset" do
    log = @asset.maintenance_logs.create!(
      content: "Bơm ga máy lạnh",
      cost: 300_000,
      performed_on: Date.current
    )
    assert_equal 1, @asset.maintenance_logs.count

    @asset.destroy
    assert_not MaintenanceLog.exists?(log.id)
  end
end
