require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  setup do
    @landlord_user = create_landlord(tel: "0901111111", password: "Password123")
    @tenant_user = create_tenant(tel: "0902222222", password: "Password123")
  end

  test "visiting login page from root and verifying form elements" do
    visit root_url
    assert_selector "a[href='#{login_path}']", text: /Đăng nhập|Login/i, wait: 5
    click_on "Đăng nhập"

    assert_current_path login_path
    assert_selector "input[name='user[tel]']"
    assert_selector "input[name='user[password]']"
  end

  test "failed login with incorrect password shows validation alert" do
    visit login_path

    find("[data-role-selector-value='landlord']", wait: 5).click
    fill_in "user[tel]", with: @landlord_user.tel
    fill_in "user[password]", with: "WrongPassword123"
    find("button[type='submit']").click

    assert_selector ".alert, .text-danger, .invalid-feedback, #flash", wait: 5
  end

  test "successful landlord login navigates to landlord area" do
    sign_in_as(@landlord_user)

    # Landlord is redirected to landlord dashboard or landlord area
    assert_no_current_path login_path, wait: 5
    assert_text @landlord_user.fullname
  end

  test "successful tenant login navigates to tenant dashboard" do
    sign_in_as(@tenant_user)

    # Tenant is redirected to tenant dashboard
    assert_no_current_path login_path, wait: 5
    assert_text @tenant_user.fullname
  end

  test "logging out clears session and returns to root" do
    sign_in_as(@tenant_user)
    assert_text @tenant_user.fullname

    # Visit logout endpoint
    visit logout_path
    assert_current_path root_path
  end
end
