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

  test "password must be minimum 8 characters" do
    @admin.password = "pass1"
    @admin.password_confirmation = "pass1"
    assert_not @admin.valid?
  end

  test "super_admin? returns correct boolean" do
    assert @admin.super_admin?
    @admin.role = "support"
    assert_not @admin.super_admin?
  end
end
