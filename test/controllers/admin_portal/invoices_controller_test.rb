require "test_helper"

class AdminPortal::InvoicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Admin.create!(
      email: "superadmin_invoice@leanhouse.vn",
      fullname: "Super Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @support = Admin.create!(
      email: "support_invoice@leanhouse.vn",
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
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: 1.month.ago.to_date
    )

    @invoice1 = @house.invoices.create!(
      code: "INV-ADMIN-001",
      title: "Tiền phòng tháng này",
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      subtotal: 3_500_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_500_000
    )
    @invoice1.invoice_items.create!(
      name: "Tiền phòng 101",
      item_type: :rent,
      unit_price: 3_000_000,
      quantity: 1,
      unit: "tháng",
      amount: 3_000_000
    )

    @invoice2 = @house.invoices.create!(
      code: "INV-ADMIN-002",
      title: "Tiền phòng tháng trước",
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      invoice_type: "individual",
      billing_month: 1.month.ago.beginning_of_month,
      due_date: 1.month.ago.to_date + 5.days,
      status: :paid,
      subtotal: 2_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 2_000_000,
      paid_at: 1.month.ago,
      payment_method: "transfer",
      paid_by: @tenant_user,
      paid_by_role: "tenant"
    )
  end

  def login_as(admin)
    post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
  end

  test "unauthenticated user cannot access admin house invoices index or show" do
    get admin_house_invoices_url(@house)
    assert_redirected_to admin_login_url

    get admin_invoice_url(@invoice1)
    assert_redirected_to admin_login_url
  end

  test "support admin can view house invoices index" do
    login_as(@support)
    get admin_house_invoices_url(@house)
    assert_response :success
    assert_includes response.body, "INV-ADMIN-001"
    assert_includes response.body, "INV-ADMIN-002"
    assert_includes response.body, @house.name
  end

  test "super admin can view house invoices index with KPI counters" do
    login_as(@admin)
    get admin_house_invoices_url(@house)
    assert_response :success
    assert_select ".admin-card", minimum: 2
    assert_includes response.body, "INV-ADMIN-001"
    assert_includes response.body, "INV-ADMIN-002"
  end

  test "admin can search invoices by code" do
    login_as(@admin)
    get admin_house_invoices_url(@house, q: "ADMIN-001")
    assert_response :success
    assert_includes response.body, "INV-ADMIN-001"
    assert_not_includes response.body, "INV-ADMIN-002"
  end

  test "admin can filter invoices by state" do
    login_as(@admin)
    get admin_house_invoices_url(@house, state: "paid")
    assert_response :success
    assert_includes response.body, "INV-ADMIN-002"
    assert_not_includes response.body, "INV-ADMIN-001"
  end

  test "admin can view invoice detail modal in read-only mode" do
    login_as(@admin)
    get admin_invoice_url(@invoice1)
    assert_response :success
    assert_select "#invoiceDetailModal"
    assert_includes response.body, "INV-ADMIN-001"
    assert_includes response.body, "Tiền phòng 101"
    assert_includes response.body, "3.500.000"

    # Confirms no mutation buttons exist for admin
    assert_select "button[data-bs-target='#markPaidModal']", 0
    assert_select "button[data-bs-target='#undoPaidModal']", 0
    assert_select "form[action*='mark_paid']", 0
    assert_select "form[action*='undo_paid']", 0
  end

  test "admin invoice detail displays paid info and fallback text when no proof uploaded" do
    login_as(@admin)
    get admin_invoice_url(@invoice2)
    assert_response :success
    assert_includes response.body, "INV-ADMIN-002"
    assert_includes response.body, I18n.t("invoice.no_payment_proof")
    assert_includes response.body, @tenant_user.fullname
  end

  test "admin invoice detail displays undo reason banner when payment was undone" do
    @invoice1.update!(
      status: :pending,
      undo_reason: "Giao dịch lỗi, chuyển khoản sai số tài khoản",
      undone_at: Time.current,
      undone_by: @landlord_user
    )

    login_as(@admin)
    get admin_invoice_url(@invoice1)
    assert_response :success
    assert_select ".undo-reason-banner"
    assert_includes response.body, "Giao dịch lỗi, chuyển khoản sai số tài khoản"
    assert_includes response.body, @landlord_user.fullname
  end

  test "tenant user detail page displays invoice history" do
    login_as(@admin)
    get admin_user_url(@tenant_user)
    assert_response :success
    assert_includes response.body, I18n.t("admin.users.invoice_history")
    assert_select "turbo-frame#admin_user_invoices"

    get invoices_admin_user_url(@tenant_user)
    assert_response :success
    assert_includes response.body, "INV-ADMIN-002"
  end
end
