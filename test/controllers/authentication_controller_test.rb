require "test_helper"

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  test "should get sign_up" do
    get authentication_sign_up_url
    assert_response :success
  end

  test "should get log_in" do
    get authentication_log_in_url
    assert_response :success
  end
end
