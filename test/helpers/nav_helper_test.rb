require "test_helper"

class NavHelperTest < ActionView::TestCase
  include NavHelper

  setup do
    @landlord = create_landlord(tel: "0901112222", fullname: "Nguyen Van Chu Nha")
    @tenant = create_tenant(tel: "0903334444", fullname: "Tran Thi Nguoi Thue")
    @admin = Admin.create!(
      fullname: "Super Admin User",
      email: "super_test@leanhouse.vn",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )
  end

  test "get_role returns landlord for landlord user" do
    assert_equal I18n.t("role.landlord"), get_role(@landlord)
  end

  test "get_role returns tenant for tenant user" do
    assert_equal I18n.t("role.tenant"), get_role(@tenant)
  end

  test "get_role returns super_admin for admin" do
    expected_role = I18n.t("enums.admin.roles.super_admin", default: "Super Admin")
    assert_equal expected_role, get_role(@admin)
  end

  test "get_role prioritizes current_user when both current_user and current_admin exist in user portal" do
    self.define_singleton_method(:current_user) { @landlord }
    self.define_singleton_method(:current_admin) { @admin }
    self.define_singleton_method(:controller_path) { "landlord_portal/dashboards" }

    assert_equal I18n.t("role.landlord"), get_role
    assert_equal I18n.t("role.landlord"), get_role(@landlord)
    assert_equal I18n.t("enums.admin.roles.super_admin", default: "Super Admin"), get_role(@admin)
  end

  test "get_role prioritizes current_admin when in admin_portal controller" do
    self.define_singleton_method(:current_user) { @landlord }
    self.define_singleton_method(:current_admin) { @admin }
    self.define_singleton_method(:controller_path) { "admin_portal/dashboard" }

    expected_role = I18n.t("enums.admin.roles.super_admin", default: "Super Admin")
    assert_equal expected_role, get_role
    assert_equal expected_role, get_role(@admin)
    assert_equal I18n.t("role.landlord"), get_role(@landlord)
  end

  test "format_name formats names with middle initials" do
    assert_equal "Nguyen V. Nha", format_name("Nguyen Van Nha")
    assert_equal "OneName", format_name("OneName")
  end
end
