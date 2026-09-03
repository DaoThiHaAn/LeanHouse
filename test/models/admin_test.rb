require "test_helper"

class AdminTest < ActiveSupport::TestCase
  def setup
    @admin = Admin.new(
      email: "test_admin@leanhouse.vn",
      fullname: "Admin Test",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )
  end

  test "valid admin should be valid" do
    assert @admin.valid?
  end

  test "email must be present" do
    @admin.email = "   "
    assert_not @admin.valid?
  end

  test "email must be valid format" do
    @admin.email = "invalid-email"
    assert_not @admin.valid?
  end

  test "email must be unique case-insensitively" do
    @admin.save!
    duplicate = @admin.dup
    duplicate.email = @admin.email.upcase
    assert_not duplicate.valid?
  end

  test "fullname must be present" do
    @admin.fullname = "   "
    assert_not @admin.valid?
  end

  test "password must be between 8 and 72 characters" do
    @admin.password = "pass1"
    @admin.password_confirmation = "pass1"
    assert_not @admin.valid?

    @admin.password = "a1" * 37 # 74 chars
    @admin.password_confirmation = "a1" * 37
    assert_not @admin.valid?
  end

  test "password must contain at least one letter and at least one number" do
    @admin.password = "12345678" # numbers only
    @admin.password_confirmation = "12345678"
    assert_not @admin.valid?
    assert_includes @admin.errors[:password], "Mật khẩu phải bao gồm ít nhất 1 chữ cái (a-z) và 1 chữ số (0-9)!"

    @admin.password = "abcdefgh" # letters only
    @admin.password_confirmation = "abcdefgh"
    assert_not @admin.valid?
    assert_includes @admin.errors[:password], "Mật khẩu phải bao gồm ít nhất 1 chữ cái (a-z) và 1 chữ số (0-9)!"

    @admin.password = "SecretPass123" # both letters and numbers
    @admin.password_confirmation = "SecretPass123"
    assert @admin.valid?
  end

  test "super_admin? returns correct boolean" do
    assert @admin.super_admin?
    @admin.role = "support"
    assert_not @admin.super_admin?
  end
end
