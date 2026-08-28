require "test_helper"

class LeaveHouseRequestTest < ActiveSupport::TestCase
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

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: Date.current,
      has_contract: true
    )

    @contract = Contract.new(
      name: "Hợp đồng thuê phòng 101",
      house: @house,
      tenant: @tenant,
      landlord: @landlord,
      tenant_citizen_id: "123456789012",
      landlord_citizen_id: "987654321098",
      start_date: 1.month.ago.to_date,
      due_date: 11.months.from_now.to_date,
      temp_resid_registered: false
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "contract.png",
      content_type: "image/png"
    )
    @contract.save!

    @leave_req = LeaveHouseRequest.create!
    @request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @leave_req,
      status: :pending
    )
  end

  test "approving leave house request checks out tenant and terminates active contract" do
    assert_nil @tenant_stay.checkout_at
    assert_nil @contract.end_date

    @leave_req.approve!(@landlord_user)

    assert_equal "approved", @request.reload.status
    assert_equal @landlord_user, @request.resolved_by
    assert_not_nil @request.resolved_at

    # Tenant stay is checked out
    @tenant_stay.reload
    assert_not_nil @tenant_stay.checkout_at
    assert_not @tenant_stay.has_contract?

    # Contract is ended
    @contract.reload
    assert_equal Date.current, @contract.end_date
  end

  test "rejecting leave house request updates status and reason" do
    @leave_req.reject!(@landlord_user, "Chưa thanh toán tiền điện nước tháng này")

    assert_equal "rejected", @request.reload.status
    assert_equal "Chưa thanh toán tiền điện nước tháng này", @request.rejection_reason
    assert_equal @landlord_user, @request.resolved_by

    # Tenant stay and contract remain unchanged
    @tenant_stay.reload
    assert_nil @tenant_stay.checkout_at
    assert_nil @contract.reload.end_date
  end
end
