# frozen_string_literal: true

require "test_helper"

module AdminPortal
  class ProfilesControllerTest < ActionDispatch::IntegrationTest
    def setup
      @super_admin = Admin.create!(
        email: "super_profile@leanhouse.vn",
        fullname: "Super Admin User",
        password: "Password123!",
        password_confirmation: "Password123!",
        role: "super_admin",
        is_active: true
      )

      @support_admin = Admin.create!(
        email: "support_profile@leanhouse.vn",
        fullname: "Support Staff User",
        password: "Password123!",
        password_confirmation: "Password123!",
        role: "support",
        is_active: true
      )
    end

    def login_as(admin)
      post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
    end

    test "unauthenticated user cannot access profile edit or update" do
      get edit_admin_profile_url
      assert_redirected_to admin_login_url

      patch admin_profile_url, params: { admin: { current_password: "Password123!" } }
      assert_redirected_to admin_login_url
    end

    test "support staff can view their own profile edit page with read-only info" do
      login_as(@support_admin)
      get edit_admin_profile_url
      assert_response :success
      assert_includes response.body, "Support Staff User"
      assert_includes response.body, "support_profile@leanhouse.vn"
      assert_includes response.body, I18n.t("admin.admins.role_support")
      assert_includes response.body, I18n.t("admin.profile.current_password")
      assert_includes response.body, I18n.t("admin.profile.account_info_notice")
    end

    test "super admin can view their own profile edit page with read-only info" do
      login_as(@super_admin)
      get edit_admin_profile_url
      assert_response :success
      assert_includes response.body, "Super Admin User"
      assert_includes response.body, "super_profile@leanhouse.vn"
      assert_includes response.body, I18n.t("admin.admins.role_super_admin")
    end

    test "support staff cannot change password with blank current password" do
      login_as(@support_admin)
      patch admin_profile_url, params: {
        admin: {
          current_password: "",
          password: "NewPassword456!",
          password_confirmation: "NewPassword456!"
        }
      }
      assert_response :unprocessable_entity
      assert_select ".invalid-feedback", text: /Mật khẩu hiện tại|Current password/i
      assert @support_admin.reload.authenticate("Password123!")
    end

    test "support staff cannot change password with incorrect current password" do
      login_as(@support_admin)
      patch admin_profile_url, params: {
        admin: {
          current_password: "WrongPassword!",
          password: "NewPassword456!",
          password_confirmation: "NewPassword456!"
        }
      }
      assert_response :unprocessable_entity
      assert_select ".invalid-feedback", text: /Mật khẩu hiện tại|Current password/i
      assert @support_admin.reload.authenticate("Password123!")
    end

    test "support staff cannot change password when new password fails confirmation" do
      login_as(@support_admin)
      patch admin_profile_url, params: {
        admin: {
          current_password: "Password123!",
          password: "NewPassword456!",
          password_confirmation: "DifferentPassword789!"
        }
      }
      assert_response :unprocessable_entity
      assert @support_admin.reload.authenticate("Password123!")
    end

    test "support staff cannot change password when new password fails complexity" do
      login_as(@support_admin)
      patch admin_profile_url, params: {
        admin: {
          current_password: "Password123!",
          password: "weak",
          password_confirmation: "weak"
        }
      }
      assert_response :unprocessable_entity
      assert @support_admin.reload.authenticate("Password123!")
    end

    test "support staff can successfully change their password with valid current password" do
      login_as(@support_admin)
      patch admin_profile_url, params: {
        admin: {
          current_password: "Password123!",
          password: "NewPassword456!",
          password_confirmation: "NewPassword456!"
        }
      }
      assert_redirected_to edit_admin_profile_url
      follow_redirect!
      assert_includes flash[:notice], I18n.t("admin.profile.update_success")
      assert @support_admin.reload.authenticate("NewPassword456!")
      assert_not @support_admin.authenticate("Password123!")
    end

    test "admin staff cannot elevate their role, alter email or change fullname via profile update" do
      login_as(@support_admin)
      patch admin_profile_url, params: {
        admin: {
          fullname: "Support Try Escalating",
          role: "super_admin",
          email: "hacked@leanhouse.vn",
          current_password: "Password123!",
          password: "NewPassword456!",
          password_confirmation: "NewPassword456!"
        }
      }
      assert_redirected_to edit_admin_profile_url
      @support_admin.reload
      assert_equal "support", @support_admin.role
      assert_equal "support_profile@leanhouse.vn", @support_admin.email
      assert_equal "Support Staff User", @support_admin.fullname
      assert @support_admin.authenticate("NewPassword456!")
    end
  end
end
