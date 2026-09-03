require "test_helper"

class AdminPortal::DashboardAndUsersControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Admin.create!(
      email: "admin_dash@leanhouse.vn",
      fullname: "Dash Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @user = User.create!(
      fullname: "Nguyen Van A",
      tel: "0901234567",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: 20.years.ago.to_date,
      address: "123 Le Loi, Q1",
      role: "landlord",
      is_active: true
    )
  end

  test "should redirect dashboard to login when unauthenticated" do
    get admin_dashboard_url
    assert_redirected_to admin_login_url
  end

  test "should access dashboard when authenticated" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_dashboard_url
    assert_response :success
  end

  test "should access users list when authenticated" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_users_url
    assert_response :success
    assert_includes response.body, @user.fullname
  end

  test "should toggle user active status" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    assert @user.is_active?
    patch toggle_active_admin_user_url(@user)
    assert_redirected_to admin_users_url

    @user.reload
    assert_not @user.is_active?

    patch toggle_active_admin_user_url(@user)
    @user.reload
    assert @user.is_active?
  end

  test "should recycle user phone" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    original_tel = @user.tel
    patch recycle_phone_admin_user_url(@user)
    assert_redirected_to admin_user_url(@user)
    assert_equal I18n.t("admin.users.recycle_success", tel: original_tel), flash[:notice]

    @user.reload
    assert_not @user.is_active?
    assert @user.tel_recycled?
    assert_equal original_tel, @user.display_tel
  end

  test "should access houses list when authenticated" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_houses_url
    assert_response :success
  end

  test "should show house detail with room rent for room mode" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    landlord = Landlord.find_or_create_by!(id: @user.id)
    house = House.create!(
      landlord: landlord,
      name: "Sunny House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "101", area: 25, max_slots: 2, tenants_count: 1)
    room.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)

    get admin_house_url(house)
    assert_response :success
    assert_includes response.body, "Sunny House"
    assert_includes response.body, "3,500,000 đ"
    assert_includes response.body, "Giá phòng"
  end

  test "should show house detail with bed rent for bed mode" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    landlord = Landlord.find_or_create_by!(id: @user.id)
    house = House.create!(
      landlord: landlord,
      name: "Dorm House",
      mode: :bed,
      address_l1: "456 Street",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "201", area: 30, max_slots: 2, tenants_count: 1)
    room.create_beds(count: 2, rent: 1_200_000, deposit: 1_200_000)

    get admin_house_url(house)
    assert_response :success
    assert_includes response.body, "Dorm House"
    assert_includes response.body, "1,200,000đ"
    assert_includes response.body, "Giường"
  end

  test "should show house sidebar with links and default structure" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    landlord = Landlord.find_or_create_by!(id: @user.id)
    house = House.create!(
      landlord: landlord,
      name: "Service House",
      mode: :room,
      address_l1: "789 Street",
      address_l2: "Ward 3",
      address_l3: "District 3",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "301", area: 20, max_slots: 2, tenants_count: 1)
    room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    service = house.services.create!(name: "Điện sinh hoạt", note: "Theo công tơ riêng")
    variant = service.service_variants.create!(fee: 3500, unit: "per_kwh", is_real_time: true)
    variant.room_services.create!(room: room)

    get admin_house_url(house)
    assert_response :success
    assert_includes response.body, "Service House"
    assert_includes response.body, "301"
    assert_includes CGI.unescape_html(response.body), I18n.t("admin.houses.services_and_amenities")
    assert_includes response.body, admin_house_services_path(house)
    assert_includes response.body, admin_house_assets_path(house)
  end

  test "should access admin house services dedicated page" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    landlord = Landlord.find_or_create_by!(id: @user.id)
    house = House.create!(
      landlord: landlord,
      name: "Full Service House",
      mode: :room,
      address_l1: "789 Street",
      address_l2: "Ward 3",
      address_l3: "District 3",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "101", area: 20, max_slots: 2, tenants_count: 1)
    room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    floor.rooms.create!(name: "102", area: 20, max_slots: 2, tenants_count: 0)

    service = house.services.create!(name: "Internet Cáp Quang", note: "Tốc độ 1Gbps")
    variant = service.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    variant.room_services.create!(room: room)

    get admin_house_services_url(house)
    assert_response :success
    assert_includes response.body, "Internet Cáp Quang"
    assert_includes response.body, "Tốc độ 1Gbps"
    assert_includes response.body, "100,000đ"
    assert_includes response.body, "101"

    # Test pagination when services exceed 10
    10.times do |i|
      house.services.create!(name: "Dịch vụ phụ #{i + 1}", note: "Ghi chú #{i + 1}")
    end

    get admin_house_services_url(house, page: 2)
    assert_response :success
    assert_select ".pagination"
  end

  test "should show beds and occupant in bed mode" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    landlord = Landlord.find_or_create_by!(id: @user.id)
    tenant_user = User.create!(
      fullname: "Tran Van B",
      tel: "0987654321",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: 20.years.ago.to_date,
      address: "123 Le Loi, Q1",
      role: "tenant",
      is_active: true
    )
    tenant = Tenant.find_or_create_by!(id: tenant_user.id)

    house = House.create!(
      landlord: landlord,
      name: "Bed Occupant House",
      mode: :bed,
      address_l1: "123 Dorm Street",
      address_l2: "Ward 4",
      address_l3: "District 4",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "K101", area: 28, max_slots: 2, tenants_count: 1)
    room.create_beds(count: 2, rent: 1_500_000, deposit: 1_500_000)

    bed1 = room.beds.first
    bed1.update!(is_available: false)
    bed1.rental_unit.tenant_stays.create!(tenant: tenant, checkin_at: Date.current, has_contract: true)

    get admin_house_url(house)
    assert_response :success
    assert_includes response.body, "Bed Occupant House"
    assert_includes response.body, "Tran Van B"
    assert_includes response.body, "0987654321"
    assert_includes response.body, "1,500,000"

    # Test room name search & status filtering
    get admin_house_url(house, q: "K101")
    assert_response :success
    assert_includes response.body, "K101"

    get admin_house_url(house, floor_id: floor.id)
    assert_response :success
    assert_includes response.body, "K101"

    get admin_house_url(house, status: "occupied")
    assert_response :success
    assert_includes response.body, "K101"

    get admin_house_url(house, q: "NonExistentRoom")
    assert_response :success
    assert_includes response.body, "Không tìm thấy phòng nào"
  end

  test "should show assets card in house detail and access dedicated assets page with maintenance logs" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    landlord = Landlord.find_or_create_by!(id: @user.id)
    house = House.create!(
      landlord: landlord,
      name: "Asset House",
      mode: :room,
      address_l1: "456 Asset Street",
      address_l2: "Ward 5",
      address_l3: "District 5",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "A101", area: 25, max_slots: 2, tenants_count: 0)
    room.create_rental_unit!(rent: 4_000_000, deposit: 4_000_000)

    asset = room.assets.create!(
      category: "air_con",
      brand: "Daikin",
      model: "Inverter 1.5HP",
      price: 8_500_000,
      status: :under_repair,
      note: "Phòng khách"
    )

    log = asset.maintenance_logs.create!(
      performed_on: Date.yesterday,
      cost: 350_000,
      content: "Nạp gas và vệ sinh lưới lọc"
    )

    # 1. House detail show view
    get admin_house_url(house)
    assert_response :success
    assert_includes CGI.unescape_html(response.body), I18n.t("admin.houses.assets_and_maintenance")
    assert_includes response.body, admin_house_assets_path(house)

    # 2. Dedicated assets page
    get admin_house_assets_url(house)
    assert_response :success
    assert_includes response.body, "Máy lạnh"
    assert_includes response.body, "Daikin - Inverter 1.5HP"
    assert_includes response.body, "Đang sửa chữa"
    assert_includes response.body, "Nạp gas và vệ sinh lưới lọc"
    assert_includes response.body, "350,000 đ"
    assert_includes response.body, "A101"

    # 3. Test pagination when assets exceed 10
    10.times do |i|
      room.assets.create!(
        category: "air_conditioner",
        status: "normal",
        brand: "Brand #{i + 1}",
        price: 1_000_000
      )
    end

    get admin_house_assets_url(house, page: 2)
    assert_response :success
    assert_select ".pagination"
  end
end
