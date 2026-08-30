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
end
