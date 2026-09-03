require "test_helper"

class LandlordDashboardStatsServiceTest < ActiveSupport::TestCase
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

    @other_landlord_user = User.create!(
      fullname: "Other Landlord",
      tel: "0909999999",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "456 Other St",
      tel_verified_at: Time.current
    )
    @other_landlord = Landlord.find_or_create_by!(id: @other_landlord_user.id)

    # House 1
    @house1 = House.create!(
      landlord: @landlord,
      name: "House 1",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor1 = Floor.create!(house: @house1, name: "Tầng 1", position: 1, rooms_count: 2)
    @room1 = Room.create!(floor: @floor1, name: "P101", max_slots: 2, tenants_count: 1, area: 20.0)
    @room2 = Room.create!(floor: @floor1, name: "P102", max_slots: 3, tenants_count: 2, area: 25.0)
    @ru1 = RentalUnit.create!(rentable: @room1, rent: 3000000, deposit: 3000000)
    @ru2 = RentalUnit.create!(rentable: @room2, rent: 4000000, deposit: 4000000)

    # House 2
    @house2 = House.create!(
      landlord: @landlord,
      name: "House 2",
      mode: :room,
      address_l1: "456 Second St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 5
    )
    @floor2 = Floor.create!(house: @house2, name: "Tầng 1", position: 1, rooms_count: 1)
    @room3 = Room.create!(floor: @floor2, name: "P201", max_slots: 5, tenants_count: 1, area: 30.0)
    @ru3 = RentalUnit.create!(rentable: @room3, rent: 5000000, deposit: 5000000)

    # Tenant users
    @tenant_user1 = User.create!(
      fullname: "Tenant A",
      tel: "0911111111",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 20.years.ago.to_date,
      address: "Address A",
      tel_verified_at: Time.current
    )
    @tenant1 = Tenant.find_or_create_by!(id: @tenant_user1.id)

    @tenant_user2 = User.create!(
      fullname: "Tenant B",
      tel: "0922222222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 22.years.ago.to_date,
      address: "Address B",
      tel_verified_at: Time.current
    )
    @tenant2 = Tenant.find_or_create_by!(id: @tenant_user2.id)

    # Tenant stays
    # Stay 1: checked in this month, still staying in House 1
    @stay1 = TenantStay.create!(
      tenant: @tenant1,
      rental_unit: @ru1,
      checkin_at: Time.current.beginning_of_month + 2.days,
      checkout_at: nil,
      has_contract: true
    )

    # Stay 2: checked in 2 months ago, checked out this month in House 1
    @stay2 = TenantStay.create!(
      tenant: @tenant2,
      rental_unit: @ru2,
      checkin_at: 2.months.ago,
      checkout_at: Time.current.beginning_of_month + 5.days,
      has_contract: false
    )

    # Contracts for House 1
    # Overdue contract
    @c_overdue = create_contract(
      tenant: @tenant1,
      landlord: @landlord,
      house: @house1,
      name: "HĐ Overdue",
      start_date: 6.months.ago.to_date,
      due_date: 5.days.ago.to_date
    )

    # Nearly due contract (within 30 days)
    @c_nearly = create_contract(
      tenant: @tenant2,
      landlord: @landlord,
      house: @house1,
      name: "HĐ Nearly Due",
      start_date: 5.months.ago.to_date,
      due_date: 15.days.from_now.to_date
    )

    # Future contract (due in 60 days)
    @c_future = create_contract(
      tenant: @tenant1,
      landlord: @landlord,
      house: @house2,
      name: "HĐ Future",
      start_date: 1.month.ago.to_date,
      due_date: 60.days.from_now.to_date
    )

    # Requests
    @v_req = create_vehicle_request("59A-99999")
    @req1 = Request.create!(
      tenant: @tenant1,
      house: @house1,
      requestable: @v_req,
      status: :pending,
      created_at: Time.current
    )

    @r_req = RepairRequest.create!(
      title: "Hỏng bóng đèn",
      content: "Bóng đèn phòng 201 bị cháy"
    )
    @req2 = Request.create!(
      tenant: @tenant2,
      house: @house2,
      requestable: @r_req,
      status: :approved,
      created_at: Time.current
    )
  end

  def create_contract(tenant:, landlord:, house:, name:, start_date:, due_date:)
    c = house.contracts.build(
      tenant: tenant,
      landlord: landlord,
      name: name,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      start_date: start_date,
      due_date: due_date,
      deposit_paid: true,
      temp_resid_registered: false
    )
    c.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "contract.png",
      content_type: "image/png"
    )
    c.save!
    c
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

  test "calculates all stats across all houses" do
    stats = LandlordDashboardStatsService.call(landlord: @landlord)

    assert_nil stats[:house]
    # Tenant flow: 1 new, 1 leaved
    assert_equal 1, stats[:tenants_flow][:new_tenants]
    assert_equal 1, stats[:tenants_flow][:leaved_tenants]

    # Occupancy: House 1 has (1+2)/(2+3) = 3/5, House 2 has 1/5 -> Total: 4/10 = 40.0%
    assert_equal 10, stats[:occupancy][:total]
    assert_equal 4, stats[:occupancy][:occupied]
    assert_equal 40.0, stats[:occupancy][:rate]

    # Pending requests: 1 pending (@req1), @req2 is approved
    assert_equal 1, stats[:pending_requests_count]
    assert_not_nil stats[:pending_requests][:soonest_vehicle_request]
    assert_equal @req1.id, stats[:pending_requests][:soonest_vehicle_request][:id]
    assert_equal 6, stats[:pending_requests][:soonest_vehicle_request][:remaining_days]

    # Contracts: 1 overdue (@c_overdue), 1 nearly_due (@c_nearly), 1 future (@c_future)
    assert_equal 1, stats[:contracts][:overdue]
    assert_equal 1, stats[:contracts][:nearly_due]
    assert_equal 2, stats[:contracts][:total]
  end

  test "filters stats for a specific house" do
    stats = LandlordDashboardStatsService.call(landlord: @landlord, house_id: @house1.id)

    assert_equal @house1, stats[:house]
    assert_equal 1, stats[:tenants_flow][:new_tenants]
    assert_equal 1, stats[:tenants_flow][:leaved_tenants]

    # House 1 occupancy: 3/5 = 60.0%
    assert_equal 5, stats[:occupancy][:total]
    assert_equal 3, stats[:occupancy][:occupied]
    assert_equal 60.0, stats[:occupancy][:rate]

    # House 1 pending requests: 1
    assert_equal 1, stats[:pending_requests_count]

    # House 1 contracts: 1 overdue, 1 nearly due
    assert_equal 1, stats[:contracts][:overdue]
    assert_equal 1, stats[:contracts][:nearly_due]
    assert_equal 2, stats[:contracts][:total]
  end

  test "handles house with zero capacity gracefully" do
    empty_house = House.create!(
      landlord: @landlord,
      name: "Empty House",
      mode: :room,
      address_l1: "Empty St",
      address_l2: "Ward E",
      address_l3: "District E",
      floors_count: 0,
      inv_creation_date: 1
    )

    stats = LandlordDashboardStatsService.call(landlord: @landlord, house_id: empty_house.id)
    assert_equal 0.0, stats[:occupancy][:rate]
    assert_equal 0, stats[:occupancy][:total]
    assert_equal 0, stats[:occupancy][:occupied]
  end

  test "room transfer within the same house does not pollute new or leaved tenant counts" do
    # Tenant 3 was staying in House 1 since last month
    tenant_user3 = User.create!(
      fullname: "Tenant C",
      tel: "0933333333",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 21.years.ago.to_date,
      address: "Address C",
      tel_verified_at: Time.current
    )
    tenant3 = Tenant.find_or_create_by!(id: tenant_user3.id)

    # Initial stay in Room 1 from last month, checking out this month
    TenantStay.create!(
      tenant: tenant3,
      rental_unit: @ru1,
      checkin_at: 1.month.ago,
      checkout_at: Time.current.beginning_of_month + 10.days
    )
    # New stay in Room 2 in the same house, checkin this month, currently active
    TenantStay.create!(
      tenant: tenant3,
      rental_unit: @ru2,
      checkin_at: Time.current.beginning_of_month + 10.days,
      checkout_at: nil
    )

    stats = LandlordDashboardStatsService.call(landlord: @landlord, house_id: @house1.id)
    # Tenant 3 was already a customer and is still a customer -> not new, not leaved!
    # Original stats for House 1 was: 1 new (@stay1), 1 leaved (@stay2)
    assert_equal 1, stats[:tenants_flow][:new_tenants]
    assert_equal 1, stats[:tenants_flow][:leaved_tenants]
  end

  test "calculates correct invoice stats for all houses and specific house" do
    @house1.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-P101-0001",
      title: "Tiền phòng",
      room: @room1,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :paid,
      subtotal: 3_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_000_000,
      paid_at: Time.current
    )

    @house2.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-P201-0002",
      title: "Tiền phòng",
      room: @room3,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 2_000_000
    )

    stats_all = LandlordDashboardStatsService.call(landlord: @landlord)
    assert_equal 2, stats_all[:invoices][:total]
    assert_equal 1, stats_all[:invoices][:paid]
    assert_equal 1, stats_all[:invoices][:pending]
    assert_equal 5_000_000, stats_all[:invoices][:total_amount]
    assert_equal 3_000_000, stats_all[:invoices][:paid_amount]
    assert_equal 2_000_000, stats_all[:invoices][:pending_amount]
    assert_equal 60.0, stats_all[:invoices][:collection_rate]

    stats_h1 = LandlordDashboardStatsService.call(landlord: @landlord, house_id: @house1.id)
    assert_equal 1, stats_h1[:invoices][:total]
    assert_equal 1, stats_h1[:invoices][:paid]
    assert_equal 0, stats_h1[:invoices][:pending]
    assert_equal 3_000_000, stats_h1[:invoices][:total_amount]
    assert_equal 100.0, stats_h1[:invoices][:collection_rate]
  end
end
