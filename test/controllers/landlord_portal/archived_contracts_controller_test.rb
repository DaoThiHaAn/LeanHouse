require "test_helper"

class LandlordPortal::ArchivedContractsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @landlord_user = User.create!(
      fullname: "Landlord Archive Test",
      tel: "0901234999",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Le Loi, Q1",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @other_landlord_user = User.create!(
      fullname: "Other Landlord",
      tel: "0901234888",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "female",
      bday: 40.years.ago.to_date,
      address: "456 Tran Hung Dao, Q5",
      tel_verified_at: Time.current
    )
    @other_landlord = Landlord.find_or_create_by!(id: @other_landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Archive User",
      tel: "0909876999",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "789 Nguyen Trai, Q5",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    # Active house
    @active_house = House.create!(
      landlord: @landlord,
      name: "Active House",
      mode: :room,
      address_l1: "123 Active St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @active_floor = @active_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @active_room = @active_floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 20.0)

    # Deleted house
    @deleted_house = House.create!(
      landlord: @landlord,
      name: "Deleted House",
      mode: :room,
      address_l1: "456 Deleted St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1,
      is_deleted: true
    )
    @deleted_floor = @deleted_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @deleted_room = @deleted_floor.rooms.create!(name: "201", max_slots: 2, tenants_count: 0, area: 20.0)

    # Contract for active house
    @active_contract = @active_house.contracts.build(
      landlord: @landlord,
      tenant: @tenant,
      name: "Hợp đồng phòng 101",
      start_date: 1.month.ago.to_date,
      due_date: 5.months.from_now.to_date,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109"
    )
    @active_contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @active_contract.save!

    # Contract for deleted house
    @deleted_house_contract = @deleted_house.contracts.build(
      landlord: @landlord,
      tenant: @tenant,
      name: "Hợp đồng cũ nhà đã xóa",
      start_date: 1.year.ago.to_date,
      due_date: 6.months.ago.to_date,
      end_date: 6.months.ago.to_date,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109"
    )
    @deleted_house_contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc2.png",
      content_type: "image/png"
    )
    @deleted_house_contract.save!

    # Other landlord house and contract
    @other_house = House.create!(
      landlord: @other_landlord,
      name: "Other House",
      mode: :room,
      address_l1: "999 Other St",
      address_l2: "Ward 3",
      address_l3: "District 3",
      floors_count: 1,
      inv_creation_date: 1
    )
    @other_floor = @other_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @other_room = @other_floor.rooms.create!(name: "301", max_slots: 2, tenants_count: 0, area: 20.0)
    @other_contract = @other_house.contracts.build(
      landlord: @other_landlord,
      tenant: @tenant,
      name: "Hợp đồng nhà khác",
      start_date: 2.months.ago.to_date,
      due_date: 4.months.from_now.to_date,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109"
    )
    @other_contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc3.png",
      content_type: "image/png"
    )
    @other_contract.save!
  end

  test "unauthenticated user cannot access contract archive" do
    get landlord_archived_contracts_path
    assert_redirected_to login_path
  end

  test "tenant cannot access landlord contract archive" do
    log_in_as(@tenant_user)
    get landlord_archived_contracts_path
    assert_response :forbidden
  end

  test "landlord can access contract archive and see only contracts from deleted houses" do
    log_in_as(@landlord_user)
    get landlord_archived_contracts_path
    assert_response :success
    assert_select "turbo-frame#contract_archive_table" do
      assert_select "[data-controller~=pagination-sync]"
      assert_select "[data-action~='turbo:frame-load->pagination-sync#updateUrl']"
      assert_select "[data-pagination-total-pages]"
    end
    assert_select "form[data-controller~=search][data-turbo-frame='contract_archive_table']"
    assert_select "tr##{dom_id(@deleted_house_contract)}"
    assert_select "tr##{dom_id(@active_contract)}", count: 0
    assert_select "tr##{dom_id(@other_contract)}", count: 0
  end

  test "landlord with no deleted houses sees empty state" do
    log_in_as(@other_landlord_user)
    get landlord_archived_contracts_path
    assert_response :success
    assert_select "p", text: I18n.t("form.house.no_deleted_houses")
    assert_select "turbo-frame#contract_archive_table", count: 0
    assert_select "form[data-controller~=search]", count: 0
  end

  test "landlord can filter contracts by house" do
    log_in_as(@landlord_user)
    get landlord_archived_contracts_path, params: { house_id: @deleted_house.id }
    assert_response :success
    assert_select "tr##{dom_id(@deleted_house_contract)}"
    assert_select "tr##{dom_id(@active_contract)}", count: 0
  end

  test "landlord can search contracts by tenant name or contract name" do
    log_in_as(@landlord_user)
    get landlord_archived_contracts_path, params: { q: "nhà đã xóa" }
    assert_response :success
    assert_select "tr##{dom_id(@deleted_house_contract)}"
    assert_select "tr##{dom_id(@active_contract)}", count: 0
  end

  test "landlord can view contract details of a deleted house" do
    log_in_as(@landlord_user)
    get landlord_archived_contract_path(@deleted_house_contract)
    assert_response :success
    assert_select ".alert-danger", text: /#{I18n.t("form.contract.deleted_house_notice")}/
  end

  test "landlord cannot view active house contract in archive" do
    log_in_as(@landlord_user)
    get landlord_archived_contract_path(@active_contract)
    assert_response :not_found
  end

  test "landlord cannot view another landlord's contract" do
    log_in_as(@landlord_user)
    get landlord_archived_contract_path(@other_contract)
    assert_response :not_found
  end

  private

  def log_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123!",
        role: user.role
      }
    }
  end
end
