require "test_helper"

class MaintenanceLogTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "0909998877",
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
    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
    @asset = @room.assets.create!(
      category: "fridge",
      price: 6_000_000,
      brand: "Toshiba",
      purchased_at: Date.current,
      status: :normal
    )
  end

  test "valid maintenance log" do
    log = @asset.maintenance_logs.build(
      performed_on: Date.new(2025, 5, 6),
      cost: 100_000,
      content: "  Bơm gas   "
    )
    assert log.valid?
    log.save!
    assert_equal "Bơm gas", log.content
  end

  test "invalid without performed_on" do
    log = @asset.maintenance_logs.build(performed_on: nil, cost: 50_000, content: "Sửa chữa")
    assert_not log.valid?
    assert log.errors[:performed_on].any?
  end

  test "invalid without content or content too long" do
    log = @asset.maintenance_logs.build(performed_on: Date.current, cost: 50_000, content: "")
    assert_not log.valid?
    assert log.errors[:content].any?

    long_content_log = @asset.maintenance_logs.build(performed_on: Date.current, cost: 50_000, content: "a" * 201)
    assert_not long_content_log.valid?
    assert long_content_log.errors[:content].any?
  end

  test "invalid cost" do
    log_negative = @asset.maintenance_logs.build(performed_on: Date.current, cost: -1, content: "Test")
    assert_not log_negative.valid?

    log_exceed = @asset.maintenance_logs.build(performed_on: Date.current, cost: 1_000_000_001, content: "Test")
    assert_not log_exceed.valid?
  end
end
