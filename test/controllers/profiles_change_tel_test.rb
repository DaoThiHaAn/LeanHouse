require "test_helper"

class ProfilesChangeTelTest < ActionDispatch::IntegrationTest
  setup do
    @landlord = User.create!(
      fullname: "Nguyen Van Landlord",
      tel: "0901111111",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "123 Street",
      tel_verified_at: Time.current
    )
    Landlord.find_or_create_by!(id: @landlord.id)

    @other_landlord = User.create!(
      fullname: "Tran Van Other",
      tel: "0902222222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "456 Street",
      tel_verified_at: Time.current
    )
    Landlord.find_or_create_by!(id: @other_landlord.id)

    @tenant = User.create!(
      fullname: "Le Thi Tenant",
      tel: "0903333333",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 20.years.ago.to_date,
      address: "789 Street",
      tel_verified_at: Time.current
    )
    Tenant.find_or_create_by!(id: @tenant.id)
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "landlord can view new_tel page" do
    sign_in_as(@landlord)
    get new_tel_landlord_profile_path

    assert_response :success
    assert_select "input[name='tel']"
  end

  test "landlord change_tel validation failure on same tel" do
    sign_in_as(@landlord)
    post change_tel_landlord_profile_path, params: { tel: @landlord.tel }

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.models.user.attributes.tel.same_as_current")
  end

  test "landlord change_tel validation failure on already registered tel in same role" do
    sign_in_as(@landlord)
    post change_tel_landlord_profile_path, params: { tel: @other_landlord.tel }

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("activerecord.errors.models.user.attributes.tel.existed_acc")
  end

  test "landlord change_tel succeeds with valid new tel and redirects to otp input" do
    sign_in_as(@landlord)
    post change_tel_landlord_profile_path, params: { tel: "0909999888" }

    assert_redirected_to otp_input_path
    assert_equal "0909999888", session[:pending_new_tel]
    assert_equal true, session[:is_change_tel]
    assert @landlord.reload.otp_code.present?
  end

  test "tenant can view new_tel page" do
    sign_in_as(@tenant)
    get new_tel_tenant_profile_path

    assert_response :success
    assert_select "input[name='tel']"
  end

  test "tenant change_tel succeeds with valid new tel and redirects to otp input" do
    sign_in_as(@tenant)
    post change_tel_tenant_profile_path, params: { tel: "0909999777" }

    assert_redirected_to otp_input_path
    assert_equal "0909999777", session[:pending_new_tel]
    assert_equal true, session[:is_change_tel]
    assert @tenant.reload.otp_code.present?
  end

  test "verify_otp fails with wrong code for change_tel" do
    sign_in_as(@landlord)
    post change_tel_landlord_profile_path, params: { tel: "0909999888" }

    post verify_otp_path, params: { otp: "000000" }

    assert_response :unprocessable_entity
    assert_not_equal "0909999888", @landlord.reload.tel
  end

  test "verify_otp succeeds for landlord change_tel: updates phone, creates notification, redirects to profile" do
    sign_in_as(@landlord)
    post change_tel_landlord_profile_path, params: { tel: "0909999888" }

    otp = @landlord.reload.otp_code
    assert_difference -> { @landlord.notifications.count }, 1 do
      post verify_otp_path, params: { otp: otp }
    end

    assert_redirected_to landlord_profile_path
    assert_equal "0909999888", @landlord.reload.tel
    assert_nil session[:is_change_tel]
    assert_nil session[:pending_new_tel]

    latest_noti = @landlord.notifications.last
    assert_equal I18n.t("noti.titles.tel_changed"), latest_noti.title
    assert_includes latest_noti.message, "0909999888"
  end

  test "verify_otp succeeds for tenant change_tel: updates phone, creates notification, redirects to profile" do
    sign_in_as(@tenant)
    post change_tel_tenant_profile_path, params: { tel: "0909999777" }

    otp = @tenant.reload.otp_code
    assert_difference -> { @tenant.notifications.count }, 1 do
      post verify_otp_path, params: { otp: otp }
    end

    assert_redirected_to tenant_profile_path
    assert_equal "0909999777", @tenant.reload.tel
    assert_nil session[:is_change_tel]
    assert_nil session[:pending_new_tel]

    latest_noti = @tenant.notifications.last
    assert_equal I18n.t("noti.titles.tel_changed"), latest_noti.title
    assert_includes latest_noti.message, "0909999777"
  end

  test "resend_otp generates new code in change_tel flow" do
    sign_in_as(@landlord)
    post change_tel_landlord_profile_path, params: { tel: "0909999888" }

    old_otp = @landlord.reload.otp_code
    post resend_otp_path

    assert_redirected_to otp_input_path
    assert_equal true, session[:is_change_tel]
    assert @landlord.reload.otp_code.present?
  end

  test "landlord can view profile with personal info form" do
    sign_in_as(@landlord)
    get landlord_profile_path

    assert_response :success
    assert_select "input[name='user[fullname]'][value='#{@landlord.fullname}']"
    assert_select "input[name='user[bday]'][value='#{@landlord.bday}']"
    assert_select "input[name='user[address]'][value='#{@landlord.address}']"
  end

  test "landlord update personal info succeeds with valid attributes" do
    sign_in_as(@landlord)
    patch landlord_profile_path, params: {
      user: {
        fullname: "Nguyen Van Updated",
        sex: "female",
        bday: "1992-04-10",
        address: "999 New Road"
      }
    }

    assert_redirected_to landlord_profile_path
    @landlord.reload
    assert_equal "Nguyen Van Updated", @landlord.fullname
    assert_equal "female", @landlord.sex
    assert_equal Date.new(1992, 4, 10), @landlord.bday
    assert_equal "999 New Road", @landlord.address
  end

  test "landlord update personal info fails with invalid attributes" do
    sign_in_as(@landlord)
    patch landlord_profile_path, params: {
      user: {
        fullname: "",
        bday: Date.current
      }
    }

    assert_response :unprocessable_entity
    assert_not_equal "", @landlord.reload.fullname
  end

  test "tenant update personal info succeeds with valid attributes" do
    sign_in_as(@tenant)
    patch tenant_profile_path, params: {
      user: {
        fullname: "Le Thi Updated",
        sex: "male",
        bday: "2000-01-01",
        address: "777 Tenant Avenue"
      }
    }

    assert_redirected_to tenant_profile_path
    @tenant.reload
    assert_equal "Le Thi Updated", @tenant.fullname
    assert_equal "male", @tenant.sex
    assert_equal Date.new(2000, 1, 1), @tenant.bday
    assert_equal "777 Tenant Avenue", @tenant.address
  end

  test "landlord change password flow end-to-end" do
    sign_in_as(@landlord)
    get change_password_landlord_profile_path

    assert_redirected_to otp_input_path
    assert_equal true, session[:is_reset_pw]
    assert_equal @landlord.tel, session[:pending_tel]

    otp = @landlord.reload.otp_code
    post verify_otp_path, params: { otp: otp }

    assert_redirected_to reset_pw_path
    assert_equal @landlord.tel, session[:verified_tel]

    get reset_pw_path
    assert_response :success

    patch user_path(@landlord), params: {
      user: {
        password: "NewPassword123",
        password_confirmation: "NewPassword123"
      }
    }

    assert_redirected_to landlord_profile_path
    assert_nil session[:is_reset_pw]
    assert_nil session[:verified_tel]
    assert @landlord.reload.authenticate("NewPassword123")
  end

  test "tenant change password flow end-to-end" do
    sign_in_as(@tenant)
    get change_password_tenant_profile_path

    assert_redirected_to otp_input_path
    assert_equal true, session[:is_reset_pw]

    otp = @tenant.reload.otp_code
    post verify_otp_path, params: { otp: otp }

    assert_redirected_to reset_pw_path

    patch user_path(@tenant), params: {
      user: {
        password: "TenantNewPassword123",
        password_confirmation: "TenantNewPassword123"
      }
    }

    assert_redirected_to tenant_profile_path
    assert @tenant.reload.authenticate("TenantNewPassword123")
  end

  test "landlord update avatar streams both profile_avatar and navbar_avatar" do
    sign_in_as(@landlord)
    image = fixture_file_upload("normal.png", "image/png")

    patch update_avatar_landlord_profile_path, params: {
      user: { avatar: image }
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, %(target="profile_avatar")
    assert_includes response.body, %(target="navbar_avatar")
    assert @landlord.reload.avatar.attached?
  end

  test "tenant update avatar streams both profile_avatar and navbar_avatar" do
    sign_in_as(@tenant)
    image = fixture_file_upload("normal.png", "image/png")

    patch update_avatar_tenant_profile_path, params: {
      user: { avatar: image }
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, %(target="profile_avatar")
    assert_includes response.body, %(target="navbar_avatar")
    assert @tenant.reload.avatar.attached?
  end
end
