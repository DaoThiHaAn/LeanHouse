require "test_helper"

class TenantPortal::ContractsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Le",
      tel: "0907654321",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Tenant Rd",
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
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: Date.current,
      has_contract: true
    )

    # Active contract
    @active_contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "Current Active Contract",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: 10.days.ago.to_date,
      due_date: Date.current + 6.months,
      deposit_paid: true,
      temp_resid_registered: false
    )
    @active_contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @active_contract.save!

    # Older, finished contract
    @old_contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "Old Finished Contract",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: 1.year.ago.to_date,
      due_date: 6.months.ago.to_date,
      end_date: 6.months.ago.to_date,
      deposit_paid: true,
      temp_resid_registered: false
    )
    @old_contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc2.png",
      content_type: "image/png"
    )
    @old_contract.save!
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

  test "show displays the latest active contract by default and always displays all contracts link" do
    sign_in_as(@tenant_user)

    get tenant_contract_path
    assert_response :success
    assert_includes response.body, "Current Active Contract"
    assert_includes response.body, tenant_all_contracts_path
    assert_includes response.body, I18n.t("form.contract.all_contracts")
  end

  test "top-level /contract redirects to tenant contract path" do
    get "/contract"
    assert_redirected_to tenant_contract_path
  end

  test "top-level /all-contracts redirects to tenant all contracts path" do
    get "/all-contracts"
    assert_redirected_to tenant_all_contracts_path
  end

  test "show displays no_contract view when tenant has no active contract" do
    # End the active contract
    @active_contract.update!(end_date: Date.current)
    @tenant_stay.update!(has_contract: false)

    sign_in_as(@tenant_user)

    get tenant_contract_path
    assert_response :success
    assert_includes response.body, I18n.t("form.contract.none")
    assert_includes response.body, tenant_all_contracts_path
  end

  test "show can display specific contract when id is provided and retains all contracts link and current contract link" do
    sign_in_as(@tenant_user)

    get tenant_contract_path(id: @old_contract.id)
    assert_response :success
    assert_includes response.body, "Old Finished Contract"
    assert_includes response.body, tenant_all_contracts_path
    assert_includes response.body, tenant_contract_path
  end

  test "tenant not linked to any house can access all contracts and inspect past contract" do
    # Tenant checks out of the house completely
    @tenant_stay.update!(checkout_at: Time.current, has_contract: false)

    sign_in_as(@tenant_user)

    # All contracts page should be accessible without being blocked by require_linked_house!
    get tenant_all_contracts_path
    assert_response :success
    assert_includes response.body, "Old Finished Contract"

    # Can also view specific contract detail
    get tenant_contract_path(id: @old_contract.id)
    assert_response :success
    assert_includes response.body, "Old Finished Contract"
  end

  test "index lists all contracts ordered by descending start date with landlord info and tooltip" do
    sign_in_as(@tenant_user)

    get tenant_all_contracts_path
    assert_response :success

    # Check landlord and tel
    assert_includes response.body, @landlord_user.tel
    assert_includes response.body, "Landlord Nguyen"

    # Check contracts ordered desc by start date (active contract first, then old contract)
    active_pos = response.body.index("Current Active Contract")
    old_pos = response.body.index("Old Finished Contract")
    assert active_pos < old_pos, "Expected Current Active Contract to appear before Old Finished Contract"

    # Check tooltip presence for landlord column
    assert_includes response.body, I18n.t("form.contract.landlord_info_tooltip")

    # Check link to switch back to active contract
    assert_includes response.body, tenant_contract_path
  end
end
