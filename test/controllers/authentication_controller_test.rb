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

  test "should get forgot_pw with fullname and bday fields" do
    get forgot_pw_url
    assert_response :success
    assert_select "input[name='user[fullname]']"
    assert_select "input[name='user[bday]']"
  end

  test "should display reminder note in sign_up" do
    get signup_url
    assert_response :success
    assert_includes response.body, I18n.t("auth.auth_fields_reminder_html")
  end

  test "should send otp on forgot_pw when fullname and bday match" do
    user = User.create!(
      fullname: "Nguyen Van An",
      tel: "0911223344",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: Date.new(1995, 5, 20),
      address: "123 Tran Hung Dao",
      role: "tenant",
      is_active: true,
      tel_verified_at: Time.current
    )

    post handle_forgot_pw_url, params: {
      user: {
        tel: "0911223344",
        role: "tenant",
        fullname: "Nguyen Van An",
        bday: "1995-05-20"
      }
    }

    assert_redirected_to otp_input_url
    assert_equal session[:pending_tel], "0911223344"
  end

  test "should reject forgot_pw when fullname does not match" do
    user = User.create!(
      fullname: "Nguyen Van An",
      tel: "0911223355",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: Date.new(1995, 5, 20),
      address: "123 Tran Hung Dao",
      role: "tenant",
      is_active: true,
      tel_verified_at: Time.current
    )

    post handle_forgot_pw_url, params: {
      user: {
        tel: "0911223355",
        role: "tenant",
        fullname: "Tran Van B",
        bday: "1995-05-20"
      }
    }

    assert_response :unprocessable_entity
    assert_includes flash[:alert], "Thông tin xác thực không đúng"
  end

  test "should reject forgot_pw when bday does not match" do
    user = User.create!(
      fullname: "Nguyen Van An",
      tel: "0911223366",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: Date.new(1995, 5, 20),
      address: "123 Tran Hung Dao",
      role: "tenant",
      is_active: true,
      tel_verified_at: Time.current
    )

    post handle_forgot_pw_url, params: {
      user: {
        tel: "0911223366",
        role: "tenant",
        fullname: "Nguyen Van An",
        bday: "2000-01-01"
      }
    }

    assert_response :unprocessable_entity
    assert_includes flash[:alert], "Thông tin xác thực không đúng"
  end
end
