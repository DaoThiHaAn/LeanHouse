require "test_helper"

class TenantDashboardStatsServiceTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Main St",
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
      address: "456 Side St",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Sunrise House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P101", max_slots: 2, tenants_count: 1, area: 20.0)
    @rental_unit = @room.create_rental_unit!(rent: 3000000, deposit: 3000000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: 30.days.ago,
      has_contract: true
    )

    @contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "HĐ Thuê Nhà",
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      start_date: 30.days.ago.to_date,
      due_date: Date.current + 335.days,
      deposit_paid: true,
      temp_resid_registered: false
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "contract.png",
      content_type: "image/png"
    )
    @contract.save!

    # Pending repair request
    repair_req = RepairRequest.create!(
      title: "Hỏng vòi nước",
      content: "Vòi nước bị rò rỉ"
    )
    @req_repair = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: repair_req,
      status: :pending
    )
  end

  test "calculates staying metrics and pending requests count" do
    stats = TenantDashboardStatsService.call(tenant: @tenant, tenant_stay: @tenant_stay)

    assert_equal @contract, stats[:contract]
    assert_equal 30, stats[:days_stayed]
    assert_equal 365, stats[:total_days]
    assert_equal 8, stats[:stay_progress_pct]
    assert_equal 1, stats[:pending_requests_count]
    assert_nil stats[:soonest_vehicle_request]
  end

  test "calculates soonest expiring vehicle request" do
    vehicle_req = VehicleRequest.new(
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      consent_given_at: Time.current
    )
    vehicle_req.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg.png",
      content_type: "image/png"
    )
    vehicle_req.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo.png",
      content_type: "image/png"
    )
    vehicle_req.save!

    req_vehicle = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: vehicle_req,
      status: :pending
    )
    req_vehicle.update_columns(created_at: 4.days.ago)

    stats = TenantDashboardStatsService.call(tenant: @tenant, tenant_stay: @tenant_stay)

    assert_equal 2, stats[:pending_requests_count]
    assert_not_nil stats[:soonest_vehicle_request]
    assert_equal req_vehicle.id, stats[:soonest_vehicle_request][:id]
    assert_equal 2, stats[:soonest_vehicle_request][:remaining_days]
  end

  test "handles tenant without contract gracefully" do
    @contract.destroy!
    @tenant_stay.update!(has_contract: false)

    stats = TenantDashboardStatsService.call(tenant: @tenant, tenant_stay: @tenant_stay)

    assert_nil stats[:contract]
    assert_equal 0, stats[:days_stayed]
    assert_equal 0, stats[:total_days]
    assert_equal 0, stats[:stay_progress_pct]
  end
end
