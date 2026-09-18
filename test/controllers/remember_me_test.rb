require "test_helper"

class RememberMeTest < ActionDispatch::IntegrationTest
  def setup
    @landlord = User.create!(
      fullname: "Landlord Remember",
      tel: "0988776655",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: Date.new(1990, 1, 1),
      address: "123 Le Loi, Da Nang",
      role: "landlord",
      is_active: true,
      tel_verified_at: Time.current
    )
    Landlord.find_or_create_by!(id: @landlord.id)

    @admin = Admin.create!(
      email: "admin_remember@test.com",
      fullname: "Admin Remember",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )
  end

  def session_cookie_name
    Rails.application.config.session_options[:key] || "_lean_house_session"
  end

  def simulate_browser_restart
    cookies.delete(session_cookie_name)
  end

  test "login page renders remember_me checkbox checked by default" do
    get login_path
    assert_response :success
    assert_select "input[type='checkbox'][name='user[remember_me]'][checked='checked']"
    assert_select "label[for='user_remember_me']", text: I18n.t("form.profile.remember_me")
  end

  test "logging in with remember_me sets 14-day signed cookie" do
    post handle_login_path, params: {
      user: {
        tel: @landlord.tel,
        password: "Password123!",
        role: "landlord",
        remember_me: "1"
      }
    }
    assert_redirected_to landlord_dashboard_path
    assert_equal @landlord.id, session[:user_id]
    assert cookies[:remember_user].present?

    set_cookies = Array(response.headers["Set-Cookie"])
    remember_cookie = set_cookies.find { |c| c.start_with?("remember_user=") }
    assert remember_cookie.present?
    assert_includes remember_cookie, "expires="
    assert_includes remember_cookie, "httponly"
  end

  test "remember cookie rehydrates session after browser restart (cleared session)" do
    post handle_login_path, params: {
      user: {
        tel: @landlord.tel,
        password: "Password123!",
        role: "landlord",
        remember_me: "1"
      }
    }
    assert cookies[:remember_user].present?

    # Simulate closing browser by clearing session cookie
    simulate_browser_restart

    # Visit a protected page
    get landlord_dashboard_path
    assert_response :success
    assert_equal @landlord.id, session[:user_id]
  end

  test "logging in without remember_me does not set remember cookie" do
    post handle_login_path, params: {
      user: {
        tel: @landlord.tel,
        password: "Password123!",
        role: "landlord",
        remember_me: "0"
      }
    }
    assert_redirected_to landlord_dashboard_path
    assert_equal @landlord.id, session[:user_id]
    assert cookies[:remember_user].blank?

    # Simulate closing browser by clearing session cookie
    simulate_browser_restart

    # Protected page should now redirect to login
    get landlord_dashboard_path
    assert_redirected_to login_path
  end

  test "logout deletes both session and remember cookie" do
    post handle_login_path, params: {
      user: {
        tel: @landlord.tel,
        password: "Password123!",
        role: "landlord",
        remember_me: "1"
      }
    }
    assert cookies[:remember_user].present?

    delete logout_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
    assert cookies[:remember_user].blank?

    # Verify session is not rehydrated
    get landlord_dashboard_path
    assert_redirected_to login_path
  end

  test "remember cookie is invalidated if user password changes" do
    post handle_login_path, params: {
      user: {
        tel: @landlord.tel,
        password: "Password123!",
        role: "landlord",
        remember_me: "1"
      }
    }
    assert cookies[:remember_user].present?

    # User changes password
    @landlord.update!(password: "NewPassword123!", password_confirmation: "NewPassword123!")

    # Simulate closed browser
    simulate_browser_restart

    # Accessing protected page with old remember cookie should fail
    get landlord_dashboard_path
    assert_redirected_to login_path
    assert cookies[:remember_user].blank?
  end

  test "remember cookie is invalidated if account is deactivated" do
    post handle_login_path, params: {
      user: {
        tel: @landlord.tel,
        password: "Password123!",
        role: "landlord",
        remember_me: "1"
      }
    }
    assert cookies[:remember_user].present?

    # Admin deactivates account
    @landlord.update_column(:is_active, false)

    # Simulate closed browser
    simulate_browser_restart

    get landlord_dashboard_path
    assert_redirected_to login_path
    assert cookies[:remember_user].blank?
  end

  test "admin login remains strictly session-only and never sets remember cookie" do
    post admin_handle_login_path, params: {
      email: @admin.email,
      password: "Password123!"
    }
    assert_redirected_to admin_dashboard_path
    assert_equal @admin.id, session[:admin_id]
    assert cookies[:remember_user].blank?

    # Closing browser (session cleared) logs admin out
    simulate_browser_restart
    get admin_dashboard_path
    assert_redirected_to admin_login_path
  end
end
