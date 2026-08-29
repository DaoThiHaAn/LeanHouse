require "test_helper"

class LandlordPortal::DashboardsControllerTest < ActionDispatch::IntegrationTest
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
      name: "Sunrise House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
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

  test "redirects unauthenticated user to login" do
    get landlord_dashboard_path
    assert_redirected_to login_path
  end

  test "denies tenant user from accessing landlord dashboard" do
    sign_in_as(@tenant_user)
    get landlord_dashboard_path
    assert_response :forbidden
  end

  test "renders dashboard for authenticated landlord" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path

    assert_response :success
    assert_select "h1", text: I18n.t("dashboard.landlord.title_all_houses")
    assert_select "select[name='house_id']"
    assert_select ".dashboard-stat-card", 4
  end

  test "renders dashboard filtered by specific house" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { house_id: @house.id }

    assert_response :success
    assert_select "h1", text: I18n.t("dashboard.landlord.title")
    assert_select ".dashboard-stat-card", 4
  end

  test "renders dashboard when house_id is explicitly 'all'" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { house_id: "all" }

    assert_response :success
    assert_select "h1", text: I18n.t("dashboard.landlord.title_all_houses")
    assert_select ".dashboard-stat-card", 4
  end
end
