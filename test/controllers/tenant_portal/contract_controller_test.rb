require "test_helper"

class TenantPortal::ContractControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get tenant_portal_contract_show_url
    assert_response :success
  end
end
