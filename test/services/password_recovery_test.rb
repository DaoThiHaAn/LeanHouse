require "test_helper"

class PasswordRecoveryTest < ActiveSupport::TestCase
  def setup
    Rails.cache.clear
    @user = User.create!(
      fullname: "Nguyen Van An",
      tel: "0909112233",
      password: "Password123!",
      password_confirmation: "Password123!",
      sex: "male",
      bday: Date.new(1996, 8, 15),
      address: "456 Le Duan, Q1",
      role: "tenant",
      is_active: true,
      tel_verified_at: Time.current
    )
  end

  test "successfully requests otp when all identity fields match" do
    service = PasswordRecovery.new(
      tel: "0909112233",
      role: "tenant",
      fullname: "Nguyen Van An",
      bday: "1996-08-15"
    )

    result = service.request_otp
    assert result.success?
    assert_equal :otp_sent, result.status
    assert_equal @user, result.user
    assert_not_nil result.otp
  end

  test "fails when telephone is not registered" do
    service = PasswordRecovery.new(
      tel: "0909999999",
      role: "tenant",
      fullname: "Nguyen Van An",
      bday: "1996-08-15"
    )

    result = service.request_otp
    assert_not result.success?
    assert_equal :tel_unregistered, result.status
  end

  test "fails when fullname does not match" do
    service = PasswordRecovery.new(
      tel: "0909112233",
      role: "tenant",
      fullname: "Tran Van Wrong",
      bday: "1996-08-15"
    )

    result = service.request_otp
    assert_not result.success?
    assert_equal :identity_mismatch, result.status
    assert_includes result.error_message, "còn 2 lần thử"
  end

  test "fails when bday does not match" do
    service = PasswordRecovery.new(
      tel: "0909112233",
      role: "tenant",
      fullname: "Nguyen Van An",
      bday: "2000-01-01"
    )

    result = service.request_otp
    assert_not result.success?
    assert_equal :identity_mismatch, result.status
  end

  test "locks out after exceeding maximum failed attempts (rate limiting)" do
    3.times do
      service = PasswordRecovery.new(
        tel: "0909112233",
        role: "tenant",
        fullname: "Wrong Name",
        bday: "2000-01-01"
      )
      service.request_otp
    end

    # 4th attempt should be rate limited
    service = PasswordRecovery.new(
      tel: "0909112233",
      role: "tenant",
      fullname: "Nguyen Van An",
      bday: "1996-08-15"
    )

    result = service.request_otp
    assert_not result.success?
    assert_equal :rate_limited, result.status
    assert_includes result.error_message, "quá nhiều lần"
  end
end
