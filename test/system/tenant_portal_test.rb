require "application_system_test_case"

class TenantPortalTest < ApplicationSystemTestCase
  setup do
    @tenant_user = create_tenant(tel: "0904444444", password: "Password123")
  end

  test "tenant logs in and accesses tenant dashboard" do
    sign_in_as(@tenant_user)

    assert_current_path tenant_dashboard_path
    assert_text @tenant_user.fullname
  end

  test "unauthenticated user cannot directly visit tenant dashboard" do
    visit tenant_dashboard_path

    # Redirected to login
    assert_current_path login_path
  end
end
