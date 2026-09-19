require "test_helper"

class TenantPortal::RoomsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Nguyen Van Chu",
      tel: "0901112222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Landlord Ave",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tran Thi Khach",
      tel: "0903334444",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "456 Tenant Road",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Sunshine Villa",
      mode: :room,
      address_l1: "100 Hoang Dieu",
      address_l2: "Ward 5",
      address_l3: "District 4",
      floors_count: 1,
      inv_creation_date: 5
    )

    @floor = @house.floors.create!(name: "Tang 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P.101", max_slots: 2, tenants_count: 1, area: 28.5)
    @rental_unit = @room.create_rental_unit!(rent: 4_500_000, deposit: 4_500_000)

    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: 15.days.ago,
      has_contract: true
    )

    # In-room asset
    @asset = @room.assets.create!(
      category: "air_con",
      brand: "Daikin",
      model: "Inverter 1.5HP",
      price: 11_000_000,
      purchased_at: 6.months.ago.to_date,
      status: :normal
    )
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

  test "unauthenticated user is redirected to login" do
    get tenant_room_path
    assert_redirected_to login_path
  end

  test "landlord is forbidden from tenant room page" do
    sign_in_as(@landlord_user)

    get tenant_room_path
    assert_response :forbidden
  end

  test "tenant without linked house sees no_house template" do
    unlinked_user = User.create!(
      fullname: "Unlinked Tenant",
      tel: "0909998888",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 20.years.ago.to_date,
      address: "Nowhere",
      tel_verified_at: Time.current
    )
    Tenant.find_or_create_by!(id: unlinked_user.id)

    sign_in_as(unlinked_user)
    get tenant_room_path
    assert_response :ok
    assert_includes response.body, I18n.t("form.tenant.no_house")
  end

  test "linked tenant can view room show with stats, assets, and landlord info" do
    sign_in_as(@tenant_user)

    get tenant_room_path
    assert_response :success

    # House & room information
    assert_includes response.body, "Sunshine Villa"
    assert_includes response.body, "P.101"
    assert_includes response.body, "100 Hoang Dieu"

    # Landlord details
    assert_includes response.body, @landlord_user.tel
    assert_includes response.body, "Nguyen Van Chu"

    # Room stats
    assert_includes response.body, "4,500,000 đ"
    assert_includes response.body, "28.5 m²"
    assert_includes response.body, "Ngày 5"

    # In-room asset
    assert_includes response.body, "Daikin"
    assert_includes response.body, "Inverter 1.5HP"
    assert_includes response.body, "11,000,000 đ"
    assert_includes response.body, "Máy lạnh"

    # Single occupancy empty state when alone
    assert_includes response.body, I18n.t("single_occupancy", default: "Bạn đang ở một mình trong phòng này")
  end

  test "shows roommate information and bed name in bed leasing mode" do
    bed_house = House.create!(
      landlord: @landlord,
      name: "Bed Villa",
      mode: :bed,
      address_l1: "200 Hai Ba Trung",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 10
    )
    floor = bed_house.floors.create!(name: "Tang 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Dorm 101", max_slots: 2, tenants_count: 2, area: 30.0)

    bed1 = room.beds.create!(name: "Giuong A")
    unit1 = bed1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    bed2 = room.beds.create!(name: "Giuong B")
    unit2 = bed2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    # Re-link tenant to bed1
    @tenant_stay.update!(checkout_at: Time.current)
    TenantStay.create!(
      tenant: @tenant,
      rental_unit: unit1,
      checkin_at: 5.days.ago,
      has_contract: true
    )

    # Roommate in bed2
    roommate_user = User.create!(
      fullname: "Pham Thi Ban",
      tel: "0907778888",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 21.years.ago.to_date,
      address: "Bed St",
      tel_verified_at: Time.current
    )
    roommate_tenant = Tenant.find_or_create_by!(id: roommate_user.id)
    TenantStay.create!(
      tenant: roommate_tenant,
      rental_unit: unit2,
      checkin_at: 4.days.ago,
      has_contract: true
    )

    sign_in_as(@tenant_user)
    get tenant_room_path
    assert_response :success

    assert_includes response.body, "Pham Thi Ban"
    assert_includes response.body, "0907778888"
    assert_includes response.body, "Giuong B"
  end

  test "displays attached regulation file link" do
    @house.regulation_file.attach(
      io: StringIO.new("%PDF-1.4 sample regulation pdf"),
      filename: "house_rules.pdf",
      content_type: "application/pdf"
    )
    @house.save!

    sign_in_as(@tenant_user)
    get tenant_room_path
    assert_response :success

    assert_includes response.body, "house_rules.pdf"
  end

  test "shows empty state for assets when room has no assets" do
    @room.assets.destroy_all

    sign_in_as(@tenant_user)
    get tenant_room_path
    assert_response :success

    assert_includes response.body, I18n.t("no_assets_assigned", default: "Chưa có tài sản nào được bàn giao trong phòng này")
  end

  test "displays deposit paid badge when contract has deposit_paid true" do
    create_contract(deposit_paid: true)
    @tenant_stay.update!(has_contract: true)

    sign_in_as(@tenant_user)
    get tenant_room_path
    assert_response :success

    assert_select ".deposit-paid-pill"
    assert_includes response.body, I18n.t("form.room.deposit_paid")
  end

  test "displays deposit unpaid badge when contract has deposit_paid false" do
    create_contract(deposit_paid: false)
    @tenant_stay.update!(has_contract: true)

    sign_in_as(@tenant_user)
    get tenant_room_path
    assert_response :success

    assert_select ".deposit-unpaid-pill"
    assert_includes response.body, I18n.t("form.room.deposit_unpaid")
  end

  test "displays waiting for contract registration text when tenant has no contract" do
    @tenant_stay.update!(has_contract: false)

    sign_in_as(@tenant_user)
    get tenant_room_path
    assert_response :success

    assert_includes response.body, I18n.t("form.room.waiting_for_contract")
    assert_select ".deposit-paid-pill", count: 0
    assert_select ".deposit-unpaid-pill", count: 0
  end

  private

  def create_contract(deposit_paid: true)
    contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "HD Thue Phong",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: 10.days.ago.to_date,
      due_date: Date.current + 6.months,
      deposit_paid: deposit_paid,
      temp_resid_registered: false
    )
    contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    contract.save!
    contract
  end
end
