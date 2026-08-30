require "test_helper"

class TenantPortal::DashboardControllerTest < ActionDispatch::IntegrationTest
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
      checkin_at: 30.days.ago,
      has_contract: true
    )

    # Contract started 30 days ago, due in 335 days (~1 year total)
    @contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "Contract 2026",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: 30.days.ago.to_date,
      due_date: Date.current + 335.days,
      deposit_paid: true,
      temp_resid_registered: false,
      note: "Sample note"
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @contract.save!

    # Create 2 pending repair requests
    2.times do |i|
      repair_req = RepairRequest.create!(
        title: "Broken tap #{i}",
        content: "Fix faucet"
      )
      Request.create!(
        tenant: @tenant,
        house: @house,
        requestable: repair_req,
        status: :pending
      )
    end
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "unauthenticated user is redirected to login" do
    get tenant_dashboard_path
    assert_redirected_to login_path
  end

  test "landlord is forbidden from tenant dashboard" do
    sign_in_as(@landlord_user)

    get tenant_dashboard_path
    assert_response :forbidden
  end

  test "linked tenant can view dashboard with contract stats and pending requests" do
    sign_in_as(@tenant_user)

    get tenant_dashboard_path
    assert_response :success

    # Check contract due date
    assert_includes response.body, @contract.due_date.strftime("%d/%m/%Y")
    assert_includes response.body, I18n.t("dashboard.tenant.contract_due_title")

    # Check days stayed counter and progress ring
    assert_includes response.body, I18n.t("dashboard.tenant.days_stayed", days: 30)
    assert_select ".stay-progress-ring", count: 1

    # Check pending requests count
    assert_includes response.body, I18n.t("dashboard.tenant.pending_requests_title")
    assert_select ".request-value", text: /2/
  end

  test "linked tenant with nearly-overdue vehicle request displays expiration indicator" do
    vehicle_req = VehicleRequest.new(
      license_plate: "59A-99999",
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

    req = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: vehicle_req,
      status: :pending
    )
    req.update_columns(created_at: 4.days.ago)

    sign_in_as(@tenant_user)

    get tenant_dashboard_path
    assert_response :success
    assert_includes response.body, I18n.t("dashboard.tenant.vehicle_request_due_in_days", days: 2)
  end

  test "tenant without contract shows fallback" do
    @contract.destroy!
    @tenant_stay.update!(has_contract: false)

    sign_in_as(@tenant_user)

    get tenant_dashboard_path
    assert_response :success
    assert_includes response.body, I18n.t("dashboard.tenant.no_contract")
    assert_select ".stay-progress-ring", count: 0
  end
end
