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
    @floor = Floor.create!(house: @house, name: "Tầng 1", position: 1)
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
    assert_select ".card-yellow"
    assert_select ".card-yellow", text: /#{I18n.t("dashboard.landlord.invoices_collected_rate")}/
    assert_select ".card-yellow a", count: 0
    assert_select ".house-main-container a[href*='invoices']", count: 0
    assert_select ".trend-bar-wrapper.is-current-month", 1
    assert_select ".current-month-badge", text: I18n.t("dashboard.landlord.current_month_btn")
    assert_select ".card-indigo"
    assert_select ".card-indigo .badge", text: /#{I18n.t("dashboard.landlord.all_houses")}/
  end

  test "renders dashboard filtered by specific house" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { house_id: @house.id }

    assert_response :success
    assert_select "h1", text: I18n.t("dashboard.landlord.title")
    assert_select ".dashboard-stat-card", 5
    assert_select ".card-yellow"
    assert_select ".card-yellow a[href*='invoices']", count: 1
    assert_select ".house-main-container a[href*='invoices']", count: 2
    assert_select ".card-yellow", text: /#{I18n.t("dashboard.landlord.invoices_collected_rate")}/
    assert_select ".card-indigo"
    assert_select ".card-indigo .badge", text: /#{@house.name}/
  end

  test "renders dashboard when house_id is explicitly 'all'" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { house_id: "all" }

    assert_response :success
    assert_select "h1", text: I18n.t("dashboard.landlord.title_all_houses")
    assert_select ".dashboard-stat-card", 5
    assert_select ".card-yellow"
    assert_select ".card-yellow", text: /#{I18n.t("dashboard.landlord.invoices_collected_rate")}/
    assert_select ".card-yellow a", count: 0
    assert_select ".house-main-container a[href*='invoices']", count: 0
    assert_select ".card-indigo"
  end

  test "renders dashboard in overall comparison mode by default" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path

    assert_response :success
    assert_select ".dashboard-header p.text-success-emphasis", text: I18n.t("dashboard.landlord.month_stats_label", month: Date.current.strftime("%m/%Y"))
    assert_select ".dashboard-header .badge", count: 0
    assert_select ".comparison-bar-chart"
    assert_select ".trend-bar-wrapper", 6
    assert_select ".trend-bar-wrapper[data-turbo-frame='_top']", 6
    assert_select ".trend-bar-wrapper.is-current-month", 1
    assert_select ".trend-bar-footer .current-month-badge", text: I18n.t("dashboard.landlord.current_month_btn")
    assert_select ".chip-avg"
    assert_select ".chip-max"
    assert_select ".chip-min"
  end

  test "renders dashboard in detailed mode when month param is present" do
    sign_in_as(@landlord_user)
    past_month = 2.months.ago.beginning_of_month
    get landlord_dashboard_path, params: { month: past_month.strftime("%Y-%m") }

    assert_response :success
    assert_select ".dashboard-header p.text-secondary", text: I18n.t("dashboard.landlord.realtime_ops_subtitle")
    assert_select ".dashboard-header .badge", text: /#{I18n.t("dashboard.landlord.viewing_financial_month_badge", month: past_month.strftime("%m/%Y"))}/
    assert_select ".comparison-bar-chart"
    assert_select ".trend-bar-wrapper.is-active", 1
    assert_select ".trend-bar-wrapper[data-turbo-frame='_top']", 6
    assert_select "a[data-turbo-frame='_top']", text: /#{I18n.t("dashboard.landlord.back_to_overall")}/
    assert_select "span", text: I18n.t("dashboard.landlord.total_invoiced")
  end

  test "displays fully collected badge for past month when all invoices paid" do
    room = @floor.rooms.create!(name: "Room 101", max_slots: 2, area: 20.0)
    past_month = 2.months.ago.beginning_of_month
    Invoice.create!(
      house: @house,
      room: room,
      code: "INV-PAST-01",
      billing_month: past_month,
      due_date: past_month + 10.days,
      created_by_id: @landlord.id,
      invoice_type: :room,
      status: :paid,
      subtotal: 3_000_000,
      total_amount: 3_000_000,
      paid_at: past_month + 5.days
    )

    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { month: past_month.strftime("%Y-%m") }

    assert_response :success
    assert_select ".revenue-status-badge.bg-success-subtle", text: /#{I18n.t("dashboard.landlord.fully_collected")}/
  end

  test "displays uncollected debt badge for past month with unpaid invoices" do
    room = @floor.rooms.create!(name: "Room 102", max_slots: 2, area: 20.0)
    past_month = 2.months.ago.beginning_of_month
    Invoice.create!(
      house: @house,
      room: room,
      code: "INV-PAST-02",
      billing_month: past_month,
      due_date: past_month + 10.days,
      created_by_id: @landlord.id,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_500_000,
      total_amount: 2_500_000
    )

    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { month: past_month.strftime("%Y-%m") }

    assert_response :success
    assert_select ".revenue-status-badge.bg-danger-subtle"
  end

  test "displays pending collection badge for current month with unpaid invoices" do
    room = @floor.rooms.create!(name: "Room 103", max_slots: 2, area: 20.0)
    curr_month = Date.current.beginning_of_month
    Invoice.create!(
      house: @house,
      room: room,
      code: "INV-CURR-02",
      billing_month: curr_month,
      due_date: curr_month + 10.days,
      created_by_id: @landlord.id,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_500_000,
      total_amount: 2_500_000
    )

    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { month: curr_month.strftime("%Y-%m") }

    assert_response :success
    assert_select ".revenue-status-badge.bg-warning-subtle"
  end

  test "renders header with financial badge when current month is explicitly selected in detailed mode" do
    sign_in_as(@landlord_user)
    curr_month = Date.current.beginning_of_month
    get landlord_dashboard_path, params: { month: curr_month.strftime("%Y-%m") }

    assert_response :success
    assert_select ".dashboard-header p.text-secondary", text: I18n.t("dashboard.landlord.realtime_ops_subtitle")
    assert_select ".dashboard-header .badge", text: /#{I18n.t("dashboard.landlord.viewing_financial_month_badge", month: curr_month.strftime("%m/%Y"))}/
  end

  test "falls back to current month when month param is invalid" do
    sign_in_as(@landlord_user)
    get landlord_dashboard_path, params: { month: "not-a-valid-date" }

    assert_response :success
    assert_select ".dashboard-header p.text-success-emphasis", text: I18n.t("dashboard.landlord.month_stats_label", month: Date.current.strftime("%m/%Y"))
    assert_select ".dashboard-header .badge", count: 0
    assert_select ".comparison-bar-chart"
  end
end
