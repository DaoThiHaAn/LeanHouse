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

  test "super admin can update an existing admin" do
    login_as(@super_admin)
    patch admin_admin_url(@support_admin), params: {
      admin: {
        fullname: "Updated Support Staff"
      }
    }
    assert_redirected_to admin_admins_url
    @support_admin.reload
    assert_equal "Updated Support Staff", @support_admin.fullname
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

  test "super admin cannot lock the last remaining active super admin" do
    second_super_admin = Admin.create!(
      email: "second_super@leanhouse.vn",
      fullname: "Second Super Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: false # already inactive
    )

    login_as(@super_admin)

    # Attempting to lock @super_admin when they are the only ACTIVE super admin
    patch toggle_active_admin_admin_url(@super_admin)
    assert_redirected_to admin_admins_url
    assert_includes flash[:alert], "không thể tự khóa"
    @super_admin.reload
    assert @super_admin.is_active?
  end

  test "cannot demote last remaining active super admin" do
    login_as(@super_admin)
    patch admin_admin_url(@super_admin), params: {
      admin: {
        role: "support"
      }
    }
    assert_response :unprocessable_entity
    assert_equal "Không thể hạ quyền Super Admin cuối cùng đang hoạt động!", flash[:alert]
    @super_admin.reload
    assert_equal "super_admin", @super_admin.role
  end
end
