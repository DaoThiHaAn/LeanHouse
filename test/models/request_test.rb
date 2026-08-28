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
    assert_equal 4, options.size
    assert_includes options, [ I18n.t("enums.request.status.pending"), "pending" ]
    assert_includes options, [ I18n.t("enums.request.status.approved"), "approved" ]
    assert_includes options, [ I18n.t("enums.request.status.rejected"), "rejected" ]
    assert_includes options, [ I18n.t("enums.request.status.overdue"), "overdue" ]
  end

  test "actionable? returns true for pending requests under 7 days" do
    assert @request.actionable?

    @request.update_columns(created_at: 8.days.ago)
    assert_not @request.actionable?
  end

  test "mark_as_overdue! transitions pending request to overdue" do
    @request.mark_as_overdue!
    assert_equal "overdue", @request.reload.status
  end

  test "status can only transition from pending" do
    @request.update!(status: :approved, resolved_by: @landlord_user, resolved_at: Time.current)
    assert_equal "approved", @request.reload.status

    @request.status = :overdue
    assert_not @request.valid?(:update)
    assert @request.errors[:status].any?
  end

  test "vehicle request generates watermarked registration card variant" do
    variant = @vehicle_req.watermarked_registration_card
    assert_not_nil variant
    assert variant.send(:processed?)
  end
end
