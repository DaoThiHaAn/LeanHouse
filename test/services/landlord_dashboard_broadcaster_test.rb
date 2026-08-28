require "test_helper"

class LandlordDashboardBroadcasterTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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
  end

  test "broadcast_later enqueues LandlordDashboardBroadcastJob" do
    assert_enqueued_with(job: LandlordDashboardBroadcastJob, args: [ @house.id ]) do
      LandlordDashboardBroadcaster.broadcast_later(@house.id)
    end
  end

  test "broadcast_now sends turbo stream replacements without error" do
    assert_nothing_raised do
      LandlordDashboardBroadcaster.broadcast_now(@house.id)
    end
  end

  test "broadcast_now handles blank or invalid house gracefully" do
    assert_nothing_raised do
      LandlordDashboardBroadcaster.broadcast_now(nil)
      LandlordDashboardBroadcaster.broadcast_now(-999)
    end
  end
end
