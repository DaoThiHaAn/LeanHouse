require "test_helper"

class TenantPortal::ServicesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get tenant_portal_services_show_url
    assert_response :success
  end
end
