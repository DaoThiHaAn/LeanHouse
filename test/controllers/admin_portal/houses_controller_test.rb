require "test_helper"

class AdminPortal::HousesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Admin.create!(
      email: "admin_houses_test@leanhouse.vn",
      fullname: "Admin Test",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @landlord_user = User.create!(
      fullname: "Landlord For Admin",
      tel: "0901234777",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Le Loi, Q1",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @active_house = House.create!(
      landlord: @landlord,
      name: "Admin Active House",
      mode: :room,
      address_l1: "123 Active St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @active_floor = @active_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @active_room = @active_floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 20.0)

    @deleted_house = House.create!(
      landlord: @landlord,
      name: "Admin Deleted House",
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
  end

  test "admin can list houses with all status" do
    sign_in_as_admin(@admin)
    get admin_houses_path
    assert_response :success
    assert_select "a", text: "Admin Active House"
    assert_select "a", text: "Admin Deleted House"
  end

  test "admin houses list paginates when exceeding houses per page" do
    sign_in_as_admin(@admin)

    # Create 16 more houses to exceed HOUSES_PER_PAGE (15)
    16.times do |i|
      House.create!(
        landlord: @landlord,
        name: "Admin Paginated House #{i + 1}",
        mode: :room,
        address_l1: "100 Paginated St #{i + 1}",
        address_l2: "Ward P",
        address_l3: "District P",
        floors_count: 1,
        inv_creation_date: 1
      )
    end

    get admin_houses_path(page: 2)
    assert_response :success
    assert_select ".pagination"
    assert_select "span[data-pagination-total-pages]"
  end

  test "admin can filter houses by active status" do
    sign_in_as_admin(@admin)
    get admin_houses_path, params: { status: "active" }
    assert_response :success
    assert_select "a", text: "Admin Active House"
    assert_select "a", text: "Admin Deleted House", count: 0
  end

  test "admin can filter houses by deleted status" do
    sign_in_as_admin(@admin)
    get admin_houses_path, params: { status: "deleted" }
    assert_response :success
    assert_select "a", text: "Admin Deleted House"
    assert_select "a", text: "Admin Active House", count: 0
  end

  test "admin can view deleted house show page" do
    sign_in_as_admin(@admin)
    get admin_house_path(@deleted_house)
    assert_response :success
    assert_select ".admin-deleted-banner", text: /#{Regexp.escape(I18n.t("admin.houses.deleted_banner"))}/
  end

  test "admin can view deleted house contracts tab without error" do
    sign_in_as_admin(@admin)
    get admin_house_contracts_path(@deleted_house)
    assert_response :success
  end

  test "admin can view deleted house invoices tab without error" do
    sign_in_as_admin(@admin)
    get admin_house_invoices_path(@deleted_house)
    assert_response :success
  end

  test "admin can view deleted house assets tab without error" do
    sign_in_as_admin(@admin)
    get admin_house_assets_path(@deleted_house)
    assert_response :success
  end

  test "admin can view deleted house services tab without error" do
    sign_in_as_admin(@admin)
    get admin_house_services_path(@deleted_house)
    assert_response :success
  end

  private

  def sign_in_as_admin(admin)
    post admin_handle_login_path, params: {
      email: admin.email,
      password: "Password123!"
    }
  end
end
