require "test_helper"

class AdminPortal::RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(
      email: "superadmin_requests@leanhouse.vn",
      fullname: "Super Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @support = Admin.create!(
      email: "support_requests@leanhouse.vn",
      fullname: "Support Staff",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "support",
      is_active: true
    )

    @landlord_user = User.create!(
      fullname: "Landlord Tran",
      tel: "0901234567",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Le Loi, Q1",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user_1 = User.create!(
      fullname: "Tenant Le",
      tel: "0909876543",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "456 Nguyen Trai, Q5",
      tel_verified_at: Time.current
    )
    @tenant_1 = Tenant.find_or_create_by!(id: @tenant_user_1.id)

    @tenant_user_2 = User.create!(
      fullname: "Tenant Nguyen",
      tel: "0988776655",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "789 Tran Hung Dao, Q1",
      tel_verified_at: Time.current
    )
    @tenant_2 = Tenant.find_or_create_by!(id: @tenant_user_2.id)

    @house_a = House.create!(
      landlord: @landlord,
      name: "Sunrise Villa",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @house_b = House.create!(
      landlord: @landlord,
      name: "Moonlight Mansion",
      mode: :room,
      address_l1: "456 Side St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )

    # 1. Vehicle Request (pending, in house_a, tenant_1)
    @vehicle_req = VehicleRequest.new(
      license_plate: "59A-99999",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "SH",
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

    @req_vehicle = Request.create!(
      tenant: @tenant_1,
      house: @house_a,
      requestable: @vehicle_req,
      status: :pending,
      created_at: Time.current
    )

    # 2. Repair Request (handling, in house_b, tenant_2)
    @repair_req = RepairRequest.create!(
      title: "Broken Air Conditioner",
      content: "The AC leaks water into the bedroom."
    )
    @req_repair = Request.create!(
      tenant: @tenant_2,
      house: @house_b,
      requestable: @repair_req,
      status: :handling,
      created_at: 1.day.ago
    )

    # 3. Leave House Request (rejected, in house_a, tenant_1)
    @leave_req = LeaveHouseRequest.create!
    @req_leave = Request.create!(
      tenant: @tenant_1,
      house: @house_a,
      requestable: @leave_req,
      status: :rejected,
      rejection_reason: "Contract term not fulfilled yet",
      resolved_at: Time.current,
      resolved_by: @landlord_user,
      created_at: 2.days.ago
    )
  end

  def sign_in_admin(admin = @admin)
    post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
  end

  test "should redirect to login when unauthenticated" do
    get admin_requests_url
    assert_redirected_to admin_login_url

    get admin_request_url(@req_vehicle)
    assert_redirected_to admin_login_url
  end

  test "should render requests index with stats when signed in as super admin" do
    sign_in_admin(@admin)

    get admin_requests_url
    assert_response :success
    assert_select "h1", text: I18n.t("admin.requests.title")
    assert_select ".admin-stat-card", count: 6

    # Verify no house dropdown is present
    assert_select "select[name='house_id']", count: 0

    # Verify requests are shown in table
    assert_includes response.body, I18n.t("admin.requests.handling_subtext")
    assert_includes response.body, @req_vehicle.human_request_type
    assert_includes response.body, @req_repair.human_request_type
    assert_includes response.body, @req_leave.human_request_type
    assert_includes response.body, "Sunrise Villa"
    assert_includes response.body, "Moonlight Mansion"
  end

  test "should render requests index when signed in as support admin" do
    sign_in_admin(@support)

    get admin_requests_url
    assert_response :success
    assert_includes response.body, @req_vehicle.human_request_type
  end

  test "should filter requests by search query matching house name" do
    sign_in_admin(@admin)

    get admin_requests_url, params: { q: "Sunrise" }
    assert_response :success
    assert_includes response.body, "Sunrise Villa"
    assert_not_includes response.body, "Moonlight Mansion"
  end

  test "should filter requests by search query matching tenant phone" do
    sign_in_admin(@admin)

    get admin_requests_url, params: { q: @tenant_user_2.tel }
    assert_response :success
    assert_includes response.body, "Moonlight Mansion"
    assert_includes response.body, @tenant_user_2.fullname
    assert_not_includes response.body, "Sunrise Villa"
  end

  test "should filter requests by status" do
    sign_in_admin(@admin)

    get admin_requests_url, params: { status: "handling" }
    assert_response :success
    assert_includes response.body, "Moonlight Mansion"
    assert_not_includes response.body, "Sunrise Villa"
  end

  test "should filter requests by request type" do
    sign_in_admin(@admin)

    get admin_requests_url, params: { request_type: "LeaveHouseRequest" }
    assert_response :success
    assert_includes response.body, "Sunrise Villa"
    assert_includes response.body, @req_leave.human_request_type
    assert_not_includes response.body, "Moonlight Mansion"
  end

  test "should filter requests by sent time range with max today" do
    sign_in_admin(@admin)

    # Check input fields and labels exist with max and default today
    get admin_requests_url
    assert_response :success
    assert_select "label[for='from_date']"
    assert_select "label[for='to_date']"
    assert_select "input[name='from_date'][max='#{Date.current}']"
    assert_select "input[name='to_date'][max='#{Date.current}'][value='#{Date.current}']"

    # Filter for today only (@req_vehicle created today)
    get admin_requests_url, params: { from_date: Date.current.to_s, to_date: Date.current.to_s }
    assert_response :success
    assert_select "#request_row_#{@req_vehicle.id}"
    assert_select "#request_row_#{@req_repair.id}", count: 0
    assert_select "#request_row_#{@req_leave.id}", count: 0

    # Filter for 2 days ago (@req_leave created 2.days.ago)
    get admin_requests_url, params: { from_date: 3.days.ago.to_date.to_s, to_date: 2.days.ago.to_date.to_s }
    assert_response :success
    assert_select "#request_row_#{@req_leave.id}"
    assert_select "#request_row_#{@req_vehicle.id}", count: 0
  end

  test "should render show view in modal turbo frame for vehicle request" do
    sign_in_admin(@admin)

    get admin_request_url(@req_vehicle)
    assert_response :success
    assert_select "turbo-frame#request_detail_modal" do
      assert_select ".modal-title", text: /#{@req_vehicle.human_request_type}/
      assert_includes response.body, "59A-99999"
      assert_includes response.body, "Honda"
      assert_includes response.body, "SH"
    end
  end

  test "should render show view in modal turbo frame for repair request" do
    sign_in_admin(@admin)

    get admin_request_url(@req_repair)
    assert_response :success
    assert_select "turbo-frame#request_detail_modal" do
      assert_includes response.body, "Broken Air Conditioner"
      assert_includes response.body, "The AC leaks water into the bedroom."
    end
  end

  test "should render show view with rejection reason and resolver info for rejected request" do
    sign_in_admin(@admin)

    get admin_request_url(@req_leave)
    assert_response :success
    assert_select "turbo-frame#request_detail_modal" do
      assert_includes response.body, "Contract term not fulfilled yet"
      assert_includes response.body, @landlord_user.fullname
    end
  end
end
