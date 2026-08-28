require "test_helper"

class RequestTest < ActiveSupport::TestCase
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

    @vehicle_req = VehicleRequest.new(
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
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

  test "status_options returns valid translated options" do
    options = Request.status_options
    assert_equal 6, options.size
    assert_includes options, [ I18n.t("enums.request.status.pending"), "pending" ]
    assert_includes options, [ I18n.t("enums.request.status.handling"), "handling" ]
    assert_includes options, [ I18n.t("enums.request.status.completed"), "completed" ]
    assert_includes options, [ I18n.t("enums.request.status.approved"), "approved" ]
    assert_includes options, [ I18n.t("enums.request.status.rejected"), "rejected" ]
    assert_includes options, [ I18n.t("enums.request.status.overdue"), "overdue" ]
  end

  test "actionable? returns true for pending vehicle requests under 7 days" do
    assert @request.actionable?

    @request.update_columns(created_at: 8.days.ago)
    assert_not @request.actionable?
  end

  test "actionable? returns true for repair requests in pending and handling states" do
    repair_req = RepairRequest.create!(title: "Hỏng máy giặt", content: "Máy không vắt nước được")
    repair_request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: repair_req,
      status: :pending
    )

    assert repair_request.actionable?

    # Even older than 7 days, repair request remains actionable (No auto-expiration)
    repair_request.update_columns(created_at: 10.days.ago)
    assert repair_request.actionable?

    # Handling state is actionable (can be marked completed)
    repair_request.update!(status: :handling, resolved_by: @landlord_user, resolved_at: Time.current)
    assert repair_request.actionable?

    # Completed state is terminal (no longer actionable)
    repair_request.update!(status: :completed)
    assert_not repair_request.actionable?
  end

  test "mark_as_overdue! transitions pending request to overdue" do
    @request.mark_as_overdue!
    assert_equal "overdue", @request.reload.status
  end

  test "status transitions follow state machine rules" do
    @request.update!(status: :approved, resolved_by: @landlord_user, resolved_at: Time.current)
    assert_equal "approved", @request.reload.status

    @request.status = :overdue
    assert_not @request.valid?(:update)
    assert @request.errors[:status].any?
  end

  test "repair request supports pending to handling to completed transitions" do
    repair_req = RepairRequest.create!(title: "Hỏng đèn", content: "Đèn trần bị chập")
    repair_request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: repair_req,
      status: :pending
    )

    repair_request.update!(status: :handling, resolved_by: @landlord_user, resolved_at: Time.current)
    assert_equal "handling", repair_request.reload.status

    repair_request.update!(status: :completed)
    assert_equal "completed", repair_request.reload.status

    # Cannot transition from completed
    repair_request.status = :pending
    assert_not repair_request.valid?(:update)
  end

  test "vehicle request generates watermarked registration card variant" do
    variant = @vehicle_req.watermarked_registration_card
    assert_not_nil variant
    assert variant.send(:processed?)
  end
end
