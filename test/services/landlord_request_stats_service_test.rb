require "test_helper"

class LandlordRequestStatsServiceTest < ActiveSupport::TestCase
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
  end

  def create_vehicle_request(created_at: Time.current, status: :pending)
    vr = VehicleRequest.new(
      license_plate: "59A-#{rand(10000..99999)}",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "Vision",
      consent_given_at: Time.current
    )
    vr.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg.png",
      content_type: "image/png"
    )
    vr.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo.png",
      content_type: "image/png"
    )
    vr.save!

    req = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: vr,
      status: status
    )
    req.update_columns(created_at: created_at)
    req
  end

  def create_repair_request(status: :pending, resolved_at: nil)
    rr = RepairRequest.create!(title: "Sửa điện", content: "Chập điện")
    req = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: rr,
      status: status,
      resolved_at: resolved_at,
      resolved_by: (resolved_at.present? ? @landlord_user : nil)
    )
    req
  end

  test "calculates correct stats for various request states" do
    travel_to Time.zone.parse("2026-09-03 12:00:00") do
      # 1. Vehicle request created today (normal pending)
      create_vehicle_request(created_at: Time.current)

      # 2. Vehicle request expiring in 1 day (after today)
      create_vehicle_request(created_at: 5.days.ago)

      # 3. Vehicle request due today (expires in 2 hours)
      create_vehicle_request(created_at: (7.days.ago + 2.hours))

      # 4. Repair request in handling
      create_repair_request(status: :handling)

      # 5. Resolved request this month
      create_repair_request(status: :completed, resolved_at: Time.current)

      stats = LandlordRequestStatsService.call(landlord: @landlord)

      assert_equal 3, stats[:pending_count]
      assert_equal 1, stats[:handling_count]
      assert_equal 1, stats[:due_today_count]
      assert_equal 1, stats[:expiring_after_today_count]
      assert_equal 2, stats[:expiring_total_count]
      assert_equal 1, stats[:resolved_this_month_count]
    end
  end

  test "returns zeros when landlord has no requests" do
    stats = LandlordRequestStatsService.call(landlord: @landlord)

    assert_equal 0, stats[:pending_count]
    assert_equal 0, stats[:handling_count]
    assert_equal 0, stats[:due_today_count]
    assert_equal 0, stats[:expiring_after_today_count]
    assert_equal 0, stats[:expiring_total_count]
    assert_equal 0, stats[:resolved_this_month_count]
  end
end
