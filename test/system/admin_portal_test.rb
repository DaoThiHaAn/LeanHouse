# frozen_string_literal: true

require "application_system_test_case"

class AdminPortalTest < ApplicationSystemTestCase
  setup do
    @admin = Admin.create!(
      fullname: "System Super Admin",
      email: "superadmin@leanhouse.vn",
      password: "AdminPassword123",
      password_confirmation: "AdminPassword123",
      role: "super_admin",
      is_active: true
    )
  end

  test "admin login page toggles password visibility via Stimulus and authenticates super_admin" do
    visit admin_login_path

    assert_selector ".admin-login-card", wait: 5
    assert_selector "input[name='email']"
    assert_selector "input[name='password'][type='password']"

    # Test Stimulus password visibility toggle
    find("[data-action='click->form#togglePasswordVisibility']").click
    assert_selector "input[name='password'][type='text']", wait: 5

    fill_in "email", with: @admin.email
    fill_in "password", with: "AdminPassword123"
    find("button[type='submit']").click

    assert_no_current_path admin_login_path, wait: 5
    assert_text "System S. Admin"
  end

  test "admin login with invalid credentials shows alert and remains on login page" do
    visit admin_login_path

    fill_in "email", with: @admin.email
    fill_in "password", with: "WrongPassword999"
    find("button[type='submit']").click

    assert_current_path admin_login_path, wait: 5
    assert_selector ".alert, #flash", wait: 5
  end

  test "authenticated super_admin can browse and filter users and view issue reports" do
    landlord_user = create_landlord(tel: "0909998877", fullname: "Landlord For Admin Check")
    IssueReport.create!(
      email: "tenant_help@leanhouse.vn",
      title: "Lỗi hiển thị hóa đơn",
      description: "Không xem được chi tiết hóa đơn trên điện thoại"
    )

    visit admin_login_path
    fill_in "email", with: @admin.email
    fill_in "password", with: "AdminPassword123"
    find("button[type='submit']").click
    assert_no_current_path admin_login_path, wait: 5

    visit admin_users_path
    assert_selector "#floatingRoleSelect", wait: 5
    assert_text landlord_user.tel

    select I18n.t("admin.users.filter_landlord"), from: "floatingRoleSelect"
    assert_text landlord_user.tel

    visit admin_issue_reports_path
    assert_text "Lỗi hiển thị hóa đơn", wait: 5
    assert_text "tenant_help@leanhouse.vn"
  end
end
