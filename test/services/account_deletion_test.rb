require "test_helper"

class AccountDeletionTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Delete Test",
      tel: "0908889900",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 40.years.ago.to_date,
      address: "999 Landlord Ave",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Sol House",
      mode: :room,
      address_l1: "456 Main St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = Floor.create!(house: @house, name: "Floor 1", position: 1)
    @room = Room.create!(floor: @floor, name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
  end

  test "successfully discards eligible account" do
    result = AccountDeletion.call(@landlord_user)

    assert result.success?
    @landlord_user.reload
    assert_not_nil @landlord_user.discarded_at
    assert_not @landlord_user.is_active?
  end

  test "blocks deletion and preserves account when constraints are not met" do
    @room.update!(tenants_count: 1)

    result = AccountDeletion.call(@landlord_user)

    assert_not result.success?
    assert_equal :cannot_delete, result.error
    assert_not_empty result.blockers

    @landlord_user.reload
    assert_nil @landlord_user.discarded_at
    assert @landlord_user.is_active?
  end
end
