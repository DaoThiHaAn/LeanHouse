require "test_helper"

class LandlordPortals::RequestsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get landlord_portals_requests_show_url
    assert_response :success
  end

  test "should get index" do
    get landlord_portals_requests_index_url
    assert_response :success
  end
end
