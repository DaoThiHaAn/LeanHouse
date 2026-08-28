require "test_helper"

class TenantRequestFilterTest < ActiveSupport::TestCase
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

    @house_a = House.create!(
      landlord: @landlord,
      name: "House A",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @house_b = House.create!(
      landlord: @landlord,
      name: "House B",
      mode: :room,
      address_l1: "456 Side St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor_a = @house_a.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room_a = @floor_a.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit_a = @room_a.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @stay_a = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit_a,
      checkin_at: Date.current
    )

    # Request 1 in House A, pending, created now
    @v_req1 = create_vehicle_request("59A-11111")
    @req1 = Request.create!(
      tenant: @tenant,
      house: @house_a,
      requestable: @v_req1,
      status: :pending,
      created_at: Time.current
    )

    # Request 2 in House A, approved, created 1 month ago
    @v_req2 = create_vehicle_request("59A-22222")
    @req2 = Request.create!(
      tenant: @tenant,
      house: @house_a,
      requestable: @v_req2,
      status: :approved,
      created_at: 1.month.ago
    )

    # Request 3 in House B, rejected, created 2 months ago
    @v_req3 = create_vehicle_request("59B-33333")
    @req3 = Request.create!(
      tenant: @tenant,
      house: @house_b,
      requestable: @v_req3,
      status: :rejected,
      rejection_reason: "Duplicate plate",
      created_at: 2.months.ago
    )
  end

  def create_vehicle_request(plate)
    vr = VehicleRequest.new(
      license_plate: plate,
      vehicle_type: :motorbike,
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
    vr
  end

  test "defaults to current house when house_id param is not provided" do
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: {},
      current_house_id: @house_a.id
    )

    assert_includes results, @req1
    assert_includes results, @req2
    assert_not_includes results, @req3
  end

  test "returns all houses when house_id is empty string" do
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "" },
      current_house_id: @house_a.id
    )

    assert_includes results, @req1
    assert_includes results, @req2
    assert_includes results, @req3
  end

  test "filters by specific house_id" do
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: @house_b.id.to_s },
      current_house_id: @house_a.id
    )

    assert_equal [ @req3 ], results.to_a
  end

  test "filters by status" do
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "", status: "pending" }
    )

    assert_equal [ @req1 ], results.to_a
  end

  test "filters by sent_month (YYYY-MM)" do
    month_str = 1.month.ago.strftime("%Y-%m")
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "", sent_month: month_str }
    )

    assert_includes results, @req2
    assert_not_includes results, @req1
    assert_not_includes results, @req3
  end

  test "filters by month and year" do
    past_date = 1.month.ago
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "", month: past_date.month.to_s, year: past_date.year.to_s }
    )

    assert_includes results, @req2
    assert_not_includes results, @req3
  end

  test "filters by year alone" do
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "", year: Date.current.year.to_s }
    )

    assert_includes results, @req1
    assert_includes results, @req2
    assert_includes results, @req3
  end

  test "filters by request_type" do
    results = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "", request_type: "VehicleRequest" }
    )

    assert_equal 3, results.size

    results_none = TenantRequestFilter.call(
      tenant: @tenant,
      params: { house_id: "", request_type: "RepairRequest" }
    )

    assert_equal 0, results_none.size
  end
end
