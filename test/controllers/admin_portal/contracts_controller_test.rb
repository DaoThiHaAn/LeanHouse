require "test_helper"

class AdminPortal::ContractsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Admin.create!(
      email: "superadmin_contract@leanhouse.vn",
      fullname: "Super Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @support = Admin.create!(
      email: "support_contract@leanhouse.vn",
      fullname: "Support Staff",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "support",
      is_active: true
    )

    @landlord_user = User.create!(
      fullname: "Landlord Tran",
      tel: "0901234567",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Le Loi, Q1",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Le",
      tel: "0909876543",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "456 Nguyen Trai, Q5",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Sunrise House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: Date.current,
      has_contract: true
    )

    @contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "HD-101 Sunrise",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: Date.current,
      due_date: Date.current + 6.months,
      deposit_paid: true,
      temp_resid_registered: true,
      temp_resid_due_date: Date.current + 6.months,
      note: "Contract note for testing"
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @contract.save!
  end

  test "should redirect to login when unauthenticated" do
    get admin_house_contracts_url(@house)
    assert_redirected_to admin_login_url

    get admin_contract_url(@contract)
    assert_redirected_to admin_login_url
  end

  test "should get house contracts index when authenticated as super admin" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_house_contracts_url(@house)
    assert_response :success
    assert_includes response.body, @contract.name
    assert_includes response.body, @tenant_user.fullname
  end

  test "should get house contracts index when authenticated as support" do
    post admin_handle_login_url, params: { email: @support.email, password: "Password123!" }

    get admin_house_contracts_url(@house)
    assert_response :success
    assert_includes response.body, @contract.name
  end

  test "should filter contracts by search query" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_house_contracts_url(@house, q: "Tenant Le")
    assert_response :success
    assert_includes response.body, @contract.name

    get admin_house_contracts_url(@house, q: "NonExistentName")
    assert_response :success
    assert_not_includes response.body, @contract.name
  end

  test "should filter contracts by state" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_house_contracts_url(@house, state: "active")
    assert_response :success
    assert_includes response.body, @contract.name

    get admin_house_contracts_url(@house, state: "finished")
    assert_response :success
    assert_not_includes response.body, @contract.name
  end

  test "should get contract show modal when authenticated" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_contract_url(@contract)
    assert_response :success
    assert_includes response.body, "contractDetailModal"
    assert_includes response.body, @contract.name
    assert_includes response.body, @contract.tenant_citizen_id
    assert_includes response.body, @contract.landlord_citizen_id
    assert_includes response.body, @contract.note
  end

  test "should show contracts with house column in tenant user detail page" do
    post admin_handle_login_url, params: { email: @admin.email, password: "Password123!" }

    get admin_user_url(@tenant_user)
    assert_response :success
    assert_select "turbo-frame#admin_user_contracts"

    get contracts_admin_user_url(@tenant_user)
    assert_response :success
    assert_includes response.body, @contract.name
    assert_includes response.body, @house.name
    assert_includes response.body, admin_contract_path(@contract)
  end
end
