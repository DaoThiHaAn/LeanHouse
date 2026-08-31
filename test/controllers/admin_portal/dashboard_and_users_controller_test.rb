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
    assert_includes response.body, "1,200,000 đ"
    assert_includes response.body, "Giá giường"
  end
end
