require "test_helper"
require "minitest/mock"

class OtpDemoSandboxTest < ActionDispatch::IntegrationTest
  setup do
    @user_params = {
      fullname: "Nguyen Van Demo",
      tel: "0988776655",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "male",
      bday: "1998-05-15",
      address: "123 Demo Street"
    }
  end

  test "demo mode generates random 6-digit OTP and verifies successfully" do
    ENV["SHOW_DEMO_OTP"] = "true"

    post users_path, params: { user: @user_params }
    assert_redirected_to otp_input_path

    user = User.kept.find_by(tel: "0988776655", role: "tenant")
    assert user.present?
    assert_match(/^\d{6}$/, user.otp_code)

    # Submitting the exact generated random OTP succeeds
    post verify_otp_path, params: { otp: user.otp_code }
    assert_redirected_to root_path
    assert_equal "Đăng ký thành công!", flash[:notice]
    assert_nil session[:pending_tel]
    assert_equal user.id, session[:user_id]
  ensure
    ENV.delete("SHOW_DEMO_OTP")
  end

  test "demo mode renders demo banner with quick fill button and random OTP" do
    ENV["SHOW_DEMO_OTP"] = "true"

    post users_path, params: { user: @user_params }
    follow_redirect!

    user = User.kept.find_by(tel: "0988776655", role: "tenant")

    assert_response :success
    assert_select "[data-action='click->otp#fillDemo']"
    assert_select "[data-action='click->otp#copyDemo']"
    assert_select ".badge.bg-warning", text: user.otp_code
  ensure
    ENV.delete("SHOW_DEMO_OTP")
  end

  test "submitting incorrect code fails even when demo mode is enabled" do
    ENV["SHOW_DEMO_OTP"] = "true"

    post users_path, params: { user: @user_params }
    assert_redirected_to otp_input_path

    user = User.kept.find_by(tel: "0988776655", role: "tenant")
    wrong_code = (user.otp_code == "123456") ? "654321" : "123456"

    post verify_otp_path, params: { otp: wrong_code }
    assert_response :unprocessable_entity
    assert_equal I18n.t("errors.wrong_otp"), flash[:alert]
  ensure
    ENV.delete("SHOW_DEMO_OTP")
  end

  test "when demo mode is disabled explicitly, demo banner is not rendered" do
    ENV["SHOW_DEMO_OTP"] = "false"
    post users_path, params: { user: @user_params }
    follow_redirect!

    assert_response :success
    assert_select "[data-action='click->otp#fillDemo']", count: 0
    assert_select ".badge.bg-warning", count: 0
  ensure
    ENV.delete("SHOW_DEMO_OTP")
  end

  test "Otp.demo_mode? defaults to true when no SMS service is configured" do
    ENV.delete("SHOW_DEMO_OTP")
    ENV.delete("ENABLE_SMS_SERVICE")
    ENV.delete("SMS_API_KEY")

    assert_equal true, Otp.demo_mode?
  end

  test "Otp.demo_mode? returns false when SMS service is enabled" do
    ENV.delete("SHOW_DEMO_OTP")
    ENV["ENABLE_SMS_SERVICE"] = "true"

    assert_equal false, Otp.demo_mode?
  ensure
    ENV.delete("ENABLE_SMS_SERVICE")
  end

  test "Otp.demo_mode? honors SHOW_DEMO_OTP override over SMS service" do
    ENV["ENABLE_SMS_SERVICE"] = "true"
    ENV["SHOW_DEMO_OTP"] = "true"

    assert_equal true, Otp.demo_mode?
  ensure
    ENV.delete("ENABLE_SMS_SERVICE")
    ENV.delete("SHOW_DEMO_OTP")
  end
end
