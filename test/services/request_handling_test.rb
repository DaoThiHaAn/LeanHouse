require "test_helper"

class RequestHandlingTest < ActiveSupport::TestCase
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
      checkin_at: Date.current
    )

    @vehicle_req = VehicleRequest.new(
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "Vision",
      consent_given_at: Time.current
    )
    @vehicle_req.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg.png",
      content_type: "image/png"
    )
    @vehicle_req.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo.png",
      content_type: "image/png"
    )
    @vehicle_req.save!

    @request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @vehicle_req,
      status: :pending
    )
  end

  test "approves request and sends notification to tenant" do
    assert_difference -> { Vehicle.count }, 1 do
      assert_difference -> { Noticed::Notification.count }, 1 do
        RequestHandling.call(
          request: @request,
          landlord_user: @landlord_user,
          decision: "approved"
        )
      end
    end

    @request.reload
    assert_equal "approved", @request.status
    assert_equal @landlord_user, @request.resolved_by
    assert_not_nil @request.resolved_at

    # Document purged
    assert_not @vehicle_req.reload.registration_card_image.attached?

    # Notification verified
    noti = Noticed::Notification.last
    assert_equal @tenant_user, noti.recipient
    assert_includes noti.event.params[:house_name], "Happy House"
  end

  test "rejects request with reason and sends notification to tenant" do
    assert_difference -> { Noticed::Notification.count }, 1 do
      RequestHandling.call(
        request: @request,
        landlord_user: @landlord_user,
        decision: "rejected",
        rejection_reason: "Ảnh cà vẹt không rõ nét"
      )
    end

    @request.reload
    assert_equal "rejected", @request.status
    assert_equal "Ảnh cà vẹt không rõ nét", @request.rejection_reason
    assert_equal @landlord_user, @request.resolved_by
    assert_not @vehicle_req.reload.registration_card_image.attached?

    noti = Noticed::Notification.last
    assert_equal @tenant_user, noti.recipient
    assert_equal "Ảnh cà vẹt không rõ nét", noti.event.params[:reason]
  end

  test "raises error when rejecting without reason" do
    assert_raises(ActiveRecord::RecordInvalid) do
      RequestHandling.call(
        request: @request,
        landlord_user: @landlord_user,
        decision: "rejected",
        rejection_reason: ""
      )
    end

    assert_equal "pending", @request.reload.status
  end

  test "raises error when request is not actionable" do
    @request.update!(status: :approved, resolved_by: @landlord_user, resolved_at: Time.current)

    assert_raises(ActiveRecord::RecordInvalid) do
      RequestHandling.call(
        request: @request,
        landlord_user: @landlord_user,
        decision: "approved"
      )
    end
  end

  test "handles repair request transition to handling and completed" do
    repair_req = RepairRequest.create!(title: "Hỏng bồn cầu", content: "Nước bị tràn liên tục")
    repair_request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: repair_req,
      status: :pending
    )

    # 1. Start Handling
    assert_difference -> { Noticed::Notification.count }, 1 do
      RequestHandling.call(
        request: repair_request,
        landlord_user: @landlord_user,
        decision: "handling"
      )
    end

    repair_request.reload
    assert_equal "handling", repair_request.status
    assert_equal @landlord_user, repair_request.resolved_by
    assert_not_nil repair_request.resolved_at

    noti1 = Noticed::Notification.last
    assert_equal @tenant_user, noti1.recipient

    # 2. Complete Repair
    assert_difference -> { Noticed::Notification.count }, 1 do
      RequestHandling.call(
        request: repair_request,
        landlord_user: @landlord_user,
        decision: "completed"
      )
    end

    repair_request.reload
    assert_equal "completed", repair_request.status
    noti2 = Noticed::Notification.last
    assert_equal @tenant_user, noti2.recipient
  end
end
