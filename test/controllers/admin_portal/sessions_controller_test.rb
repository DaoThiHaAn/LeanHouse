require "test_helper"

class AdminPortal::SessionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Admin.create!(
      email: "staff@leanhouse.vn",
      fullname: "Staff Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )
  end

  test "should get login page" do
    get admin_login_url
    assert_response :success
  end

  test "should login successfully with valid credentials" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }
    assert_redirected_to admin_dashboard_url
    assert_equal @admin.id, session[:admin_id]
  end

  test "should fail login with wrong password" do
    post admin_handle_login_url, params: { email: @admin.email, password: "WrongPassword" }
    assert_response :unprocessable_entity
    assert_nil session[:admin_id]
  end

  test "should fail login with inactive account" do
    @admin.update!(is_active: false)
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }
    assert_response :forbidden
    assert_nil session[:admin_id]
  end

  test "should logout successfully" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }
    assert_equal @admin.id, session[:admin_id]

    delete admin_logout_url
    assert_redirected_to admin_login_url
    assert_nil session[:admin_id]
  end
end
