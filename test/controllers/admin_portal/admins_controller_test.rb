require "test_helper"

class AdminPortal::AdminsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @super_admin = Admin.create!(
      email: "super_owner@leanhouse.vn",
      fullname: "Super Admin Owner",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @support_admin = Admin.create!(
      email: "staff_support@leanhouse.vn",
      fullname: "Support Staff",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "support",
      is_active: true
    )
  end

  def login_as(admin)
    post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
  end

  test "unauthenticated user cannot access admins index" do
    get admin_admins_url
    assert_redirected_to admin_login_url
  end

  test "support admin is denied access to admins index and redirected to dashboard" do
    login_as(@support_admin)
    get admin_admins_url
    assert_redirected_to admin_dashboard_url
    follow_redirect!
    assert_equal "Bạn không có quyền truy cập chức năng này.", flash[:alert]
  end

  test "support admin cannot create admin" do
    login_as(@support_admin)
    assert_no_difference("Admin.count") do
      post admin_admins_url, params: {
        admin: {
          fullname: "Hacker Admin",
          email: "hacker@leanhouse.vn",
          password: "Password123!",
          password_confirmation: "Password123!",
          role: "super_admin"
        }
      }
    end
    assert_redirected_to admin_dashboard_url
  end

  test "super admin can view admins index" do
    login_as(@super_admin)
    get admin_admins_url
    assert_response :success
    assert_includes response.body, @super_admin.fullname
    assert_includes response.body, @support_admin.fullname
  end

  test "super admin can get new admin form" do
    login_as(@super_admin)
    get new_admin_admin_url
    assert_response :success
  end

  test "super admin can create a new support admin" do
    login_as(@super_admin)
    assert_difference("Admin.count", 1) do
      post admin_admins_url, params: {
        admin: {
          fullname: "New Staff Member",
          email: "new_staff@leanhouse.vn",
          password: "Password123!",
          password_confirmation: "Password123!",
          role: "support"
        }
      }
    end
    assert_redirected_to admin_admins_url
    new_staff = Admin.find_by(email: "new_staff@leanhouse.vn")
    assert_not_nil new_staff
    assert_equal "support", new_staff.role
  end

  test "super admin can view edit page with 2 separate forms" do
    login_as(@super_admin)
    get edit_admin_admin_url(@support_admin)
    assert_response :success
    # Form 1: Account Info
    assert_select "input[type=hidden][name=form_type][value=account_info]"
    assert_select "#adminFullname"
    assert_select "#adminEmail"
    assert_select "input[type=hidden][name='admin[role]'][value=support]"
    # Form 2: Reset Password
    assert_select "input[type=hidden][name=form_type][value=password]"
    assert_select "#adminResetPassword"
    assert_select "#adminResetPasswordConfirmation"
  end

  test "super admin can update an existing admin account info via Form 1" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      form_type: "account_info",
      admin: {
        fullname: "Updated Support Staff",
        email: "updated_support@leanhouse.vn",
        role: "support"
      }
    }
    assert_redirected_to admin_admins_url
    follow_redirect!
    assert_includes flash[:notice], I18n.t("admin.admins.update_success", name: "Updated Support Staff")
    @support_admin.reload
    assert_equal "Updated Support Staff", @support_admin.fullname
    assert_equal "updated_support@leanhouse.vn", @support_admin.email
    # Password remains working
    assert @support_admin.authenticate("Password123!")
  end

  test "super admin cannot update account info with invalid email via Form 1" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      form_type: "account_info",
      admin: {
        fullname: "Updated Support Staff",
        email: "not-an-email"
      }
    }
    assert_response :unprocessable_entity
    assert_select ".invalid-feedback", text: /Email không đúng định dạng|invalid/i
    assert_not_equal "not-an-email", @support_admin.reload.email
  end

  test "super admin can reset admin password via Form 2" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      form_type: "password",
      admin: {
        password: "NewPassword789!",
        password_confirmation: "NewPassword789!"
      }
    }
    assert_redirected_to admin_admins_url
    follow_redirect!
    assert_includes flash[:notice], I18n.t("admin.admins.reset_password_success", name: @support_admin.fullname)
    @support_admin.reload
    assert @support_admin.authenticate("NewPassword789!")
    assert_not @support_admin.authenticate("Password123!")
  end

  test "super admin cannot reset password with blank password via Form 2" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      form_type: "password",
      admin: {
        password: "",
        password_confirmation: ""
      }
    }
    assert_response :unprocessable_entity
    assert_select ".invalid-feedback", text: /Mật khẩu không được để trống|blank/i
    assert @support_admin.reload.authenticate("Password123!")
  end

  test "super admin cannot reset password when confirmation does not match via Form 2" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      form_type: "password",
      admin: {
        password: "NewPassword789!",
        password_confirmation: "Mismatch123!"
      }
    }
    assert_response :unprocessable_entity
    assert @support_admin.reload.authenticate("Password123!")
  end

  test "super admin cannot reset password when complexity requirements fail via Form 2" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      form_type: "password",
      admin: {
        password: "weak",
        password_confirmation: "weak"
      }
    }
    assert_response :unprocessable_entity
    assert @support_admin.reload.authenticate("Password123!")
  end

  test "super admin can lock and unlock support staff" do
    login_as(@super_admin)

    # Lock support staff
    patch toggle_active_admin_admin_url(@support_admin)
    assert_redirected_to admin_admins_url
    @support_admin.reload
    assert_not @support_admin.is_active?

    # Unlock support staff
    patch toggle_active_admin_admin_url(@support_admin)
    assert_redirected_to admin_admins_url
    @support_admin.reload
    assert @support_admin.is_active?
  end

  test "super admin cannot lock their own account" do
    login_as(@super_admin)
    patch toggle_active_admin_admin_url(@super_admin)
    assert_redirected_to admin_admins_url
    assert_equal "Bạn không thể tự khóa tài khoản của chính mình!", flash[:alert]
    @super_admin.reload
    assert @super_admin.is_active?
  end

  test "creating new admin always enforces role support even if role super_admin is passed" do
    login_as(@super_admin)
    assert_difference("Admin.count", 1) do
      post admin_admins_url, params: {
        admin: {
          fullname: "Sneaky Super Admin",
          email: "sneaky@leanhouse.vn",
          password: "Password123!",
          password_confirmation: "Password123!",
          role: "super_admin"
        }
      }
    end
    assert_redirected_to admin_admins_url
    sneaky = Admin.find_by(email: "sneaky@leanhouse.vn")
    assert_equal "support", sneaky.role
  end

  test "super admin editing themself is redirected to profile edit" do
    login_as(@super_admin)
    get edit_admin_admin_url(@super_admin)
    assert_redirected_to edit_admin_profile_url

    patch admin_admin_url(@super_admin), params: { admin: { fullname: "New Name" } }
    assert_redirected_to edit_admin_profile_url

    get admin_admins_url
    assert_response :success
    assert_select "a[href='#{edit_admin_profile_path}']"
  end
end
