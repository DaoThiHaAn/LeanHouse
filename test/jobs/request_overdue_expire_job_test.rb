require "test_helper"

class RequestOverdueExpireJobTest < ActiveJob::TestCase
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

    @vehicle_req1 = VehicleRequest.new(
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      consent_given_at: Time.current
    )
    @vehicle_req1.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg.png",
      content_type: "image/png"
    )
    @vehicle_req1.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo.png",
      content_type: "image/png"
    )
    @vehicle_req1.save!

    @vehicle_req2 = VehicleRequest.new(
      license_plate: "59A-67890",
      vehicle_type: :motorbike,
      consent_given_at: Time.current
    )
    @vehicle_req2.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg2.png",
      content_type: "image/png"
    )
    @vehicle_req2.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo2.png",
      content_type: "image/png"
    )
    @vehicle_req2.save!

    # Expired pending request (created 8 days ago)
    @expired_request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @vehicle_req1,
      status: :pending,
      created_at: 8.days.ago
    )

    # Active pending request (created 2 days ago)
    @active_request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @vehicle_req2,
      status: :pending,
      created_at: 2.days.ago
    )
  end

  test "perform marks requests older than 7 days as overdue and leaves active requests pending" do
    assert_equal "pending", @expired_request.status
    assert_equal "pending", @active_request.status

    RequestOverdueExpireJob.perform_now

    assert_equal "overdue", @expired_request.reload.status
    assert_equal "pending", @active_request.reload.status
    assert @vehicle_req1.reload.documents_purged_at.present?
  end
end
