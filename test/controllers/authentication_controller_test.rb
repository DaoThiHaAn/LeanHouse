require "test_helper"

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  test "should get sign_up" do
    get signup_url
    assert_response :success
  end

  test "should get log_in" do
    get login_url
    assert_response :success
  end
end
