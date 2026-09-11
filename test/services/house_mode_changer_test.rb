require "test_helper"

class HouseModeChangerTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Mode",
      tel: "0903334444",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "female",
      bday: 35.years.ago.to_date,
      address: "123 Landlord Ave",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Mode Switch House",
      mode: :room,
      address_l1: "1 Mode St",
      address_l2: "Ward M",
      address_l3: "District M",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(name: "101", area: 24, max_slots: 3, tenants_count: 0)
    @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
  end

  test "converts empty house from room to bed mode" do
    result = HouseModeChanger.new(@house).call

    assert result
    @house.reload
    assert_predicate @house, :bed?

    @room.reload
    assert_nil @room.rental_unit
    assert_equal 3, @room.beds.count
    assert_equal 3, @room.max_slots

    @room.beds.each do |bed|
      assert_not_nil bed.rental_unit
      assert_equal 1_000_000, bed.rental_unit.rent
      assert_equal 1_000_000, bed.rental_unit.deposit
    end
  end

  test "converts empty house from bed to room mode" do
    # First convert to bed mode
    HouseModeChanger.new(@house).call
    @house.reload
    assert_predicate @house, :bed?

    # Now convert back to room mode
    result = HouseModeChanger.new(@house).call
    assert result

    @house.reload
    assert_predicate @house, :room?

    @room.reload
    assert_equal 0, @room.beds.count
    assert_not_nil @room.rental_unit
    assert_equal 3_000_000, @room.rental_unit.rent
    assert_equal 3_000_000, @room.rental_unit.deposit
    assert_equal 3, @room.max_slots
  end

  test "refuses to convert when house has staying tenants" do
    @room.update_columns(tenants_count: 1)

    result = HouseModeChanger.new(@house).call

    assert_not result
    @house.reload
    assert_predicate @house, :room?
  end
end
