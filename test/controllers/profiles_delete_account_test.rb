require "test_helper"

class ProfilesDeleteAccountTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Nguyen Van Landlord",
      tel: "0901111111",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Street",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
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
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Happy House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
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

  test "landlord check_delete renders confirmation when no blockers" do
    sign_in_as(@landlord_user)
    get check_delete_landlord_profile_path

    assert_response :success
    assert_select "#accountCheckDeleteConfirmModal"
  end

  test "landlord check_delete renders blocked modal when active occupants exist" do
    @room.update!(tenants_count: 1)
    sign_in_as(@landlord_user)
    get check_delete_landlord_profile_path

    assert_response :success
    assert_select "#accountCheckDeleteBlockedModal"
  end

  test "landlord successfully deletes account when no blockers" do
    sign_in_as(@landlord_user)
    delete landlord_profile_path

    assert_redirected_to root_path
    follow_redirect!
    assert_not_nil flash[:notice]

    @landlord_user.reload
    assert_not_nil @landlord_user.discarded_at
    assert_not @landlord_user.is_active?
  end

  test "landlord cannot delete account when blockers exist" do
    @room.update!(tenants_count: 1)
    sign_in_as(@landlord_user)
    delete landlord_profile_path

    assert_redirected_to landlord_profile_path
    follow_redirect!
    assert_not_nil flash[:alert]

    @landlord_user.reload
    assert_nil @landlord_user.discarded_at
    assert @landlord_user.is_active?
  end

  test "tenant check_delete renders confirmation when unlinked" do
    sign_in_as(@tenant_user)
    get check_delete_tenant_profile_path

    assert_response :success
    assert_select "#accountCheckDeleteConfirmModal"
  end

  test "tenant check_delete renders blocked when actively linked" do
    rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    TenantStay.create!(
      tenant: @tenant,
      rental_unit: rental_unit,
      checkin_at: Date.current
    )
    sign_in_as(@tenant_user)
    get check_delete_tenant_profile_path

    assert_response :success
    assert_select "#accountCheckDeleteBlockedModal"
  end

  test "tenant successfully deletes account when unlinked" do
    sign_in_as(@tenant_user)
    delete tenant_profile_path

    assert_redirected_to root_path
    follow_redirect!
    assert_not_nil flash[:notice]

    @tenant_user.reload
    assert_not_nil @tenant_user.discarded_at
    assert_not @tenant_user.is_active?
  end
end
