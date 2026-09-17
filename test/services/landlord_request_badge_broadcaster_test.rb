require "test_helper"
require "minitest/mock"

class LandlordRequestBadgeBroadcasterTest < ActiveSupport::TestCase
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
  end

  test "broadcast_now replaces landlord_requests_nav_badge on Turbo::StreamsChannel" do
    repair_req = RepairRequest.create!(title: "Sửa vòi", content: "Hỏng vòi")
    Request.create!(tenant: @tenant, house: @house, requestable: repair_req, status: :pending)

    broadcasted = false
    Turbo::StreamsChannel.stub :broadcast_replace_to, ->(stream, *rest, **options) {
      broadcasted = true
      assert_equal @landlord, stream
      assert_equal [ :requests ], rest
      assert_equal "landlord_requests_nav_badge", options[:target]
      assert_equal "landlord_portal/requests/nav_badge", options[:partial]
      assert_equal 1, options[:locals][:count]
    } do
      LandlordRequestBadgeBroadcaster.broadcast_now(@landlord)
      assert broadcasted
    end
  end

  test "broadcast_now does nothing when landlord is nil" do
    broadcasted = false
    Turbo::StreamsChannel.stub :broadcast_replace_to, ->(*_args) { broadcasted = true } do
      LandlordRequestBadgeBroadcaster.broadcast_now(nil)
      assert_not broadcasted
    end
  end
end
