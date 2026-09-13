require "test_helper"

class LandlordPortal::ArchivedInvoicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @landlord_user = User.create!(
      fullname: "Landlord Invoice Test",
      tel: "0901119999",
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
      fullname: "Other Landlord Inv",
      tel: "0901118888",
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
      tel: "0909997777",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "789 Nguyen Trai, Q5",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    # Active house for landlord
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

    # Active house invoice (MUST NOT show in archive)
    @active_invoice = @active_house.invoices.create!(
      code: "HD-ACT-001",
      title: "Hóa đơn nhà đang hoạt động",
      room: @active_room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 2_000_000
    )

    # Deleted house for landlord
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

    # Deleted house invoices (SHOULD show in archive)
    @deleted_invoice_paid = @deleted_house.invoices.create!(
      code: "HD-DEL-PAID",
      title: "Hóa đơn đã trả nhà cũ",
      room: @deleted_room,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: 2.months.ago.beginning_of_month,
      due_date: 2.months.ago.to_date + 5.days,
      invoice_type: :individual,
      status: :paid,
      payment_method: :transfer,
      paid_at: 2.months.ago,
      subtotal: 1_500_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 1_500_000
    )

    @deleted_invoice_pending = @deleted_house.invoices.create!(
      code: "HD-DEL-PEND",
      title: "Hóa đơn chờ trả nhà cũ",
      room: @deleted_room,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: 1.month.ago.beginning_of_month,
      due_date: 1.month.ago.to_date + 5.days,
      invoice_type: :individual,
      status: :pending,
      subtotal: 1_800_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 1_800_000
    )

    # Other landlord's deleted house and invoice
    @other_house = House.create!(
      landlord: @other_landlord,
      name: "Other Deleted House",
      mode: :room,
      address_l1: "999 Other St",
      address_l2: "Ward 3",
      address_l3: "District 3",
      floors_count: 1,
      inv_creation_date: 1,
      is_deleted: true
    )
    @other_floor = @other_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @other_room = @other_floor.rooms.create!(name: "301", max_slots: 2, tenants_count: 0, area: 20.0)
    @other_invoice = @other_house.invoices.create!(
      code: "HD-OTH-001",
      title: "Hóa đơn chủ khác",
      room: @other_room,
      created_by: @other_landlord_user,
      billing_month: 1.month.ago.beginning_of_month,
      due_date: 1.month.ago.to_date + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_500_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 2_500_000
    )
  end

  test "unauthenticated user cannot access invoice archive" do
    get landlord_archived_invoices_path
    assert_redirected_to login_path
  end

  test "tenant cannot access landlord invoice archive" do
    log_in_as(@tenant_user)
    get landlord_archived_invoices_path
    assert_response :forbidden
  end

  test "landlord can access invoice archive and see only invoices from deleted houses" do
    log_in_as(@landlord_user)
    get landlord_archived_invoices_path
    assert_response :success
    assert_select "turbo-frame#invoice_archive_table" do
      assert_select "[data-controller~=pagination-sync]"
      assert_select "[data-action~='turbo:frame-load->pagination-sync#updateUrl']"
      assert_select "[data-pagination-total-pages]"
    end
    assert_select "form[data-controller~=search][data-turbo-frame='invoice_archive_table']"

    assert_select "tr##{dom_id(@deleted_invoice_paid)}"
    assert_select "tr##{dom_id(@deleted_invoice_pending)}"
    assert_select "tr##{dom_id(@active_invoice)}", count: 0
    assert_select "tr##{dom_id(@other_invoice)}", count: 0
  end

  test "landlord with no deleted houses sees empty state" do
    clean_landlord_user = User.create!(
      fullname: "Clean Landlord",
      tel: "0901234777",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Clean St",
      tel_verified_at: Time.current
    )
    Landlord.find_or_create_by!(id: clean_landlord_user.id)

    log_in_as(clean_landlord_user)
    get landlord_archived_invoices_path
    assert_response :success
    assert_select "p", text: I18n.t("form.house.no_deleted_houses")
    assert_select "turbo-frame#invoice_archive_table", count: 0
    assert_select "form[data-controller~=search]", count: 0
  end

  test "landlord can filter invoices by house" do
    log_in_as(@landlord_user)
    get landlord_archived_invoices_path, params: { house_id: @deleted_house.id }
    assert_response :success
    assert_select "tr##{dom_id(@deleted_invoice_paid)}"
    assert_select "tr##{dom_id(@deleted_invoice_pending)}"
  end

  test "landlord can filter invoices by month" do
    log_in_as(@landlord_user)
    get landlord_archived_invoices_path, params: { month: 2.months.ago.strftime("%Y-%m") }
    assert_response :success
    assert_select "tr##{dom_id(@deleted_invoice_paid)}"
    assert_select "tr##{dom_id(@deleted_invoice_pending)}", count: 0
  end

  test "landlord can search invoices by code or title" do
    log_in_as(@landlord_user)
    get landlord_archived_invoices_path, params: { q: "HD-DEL-PAID" }
    assert_response :success
    assert_select "tr##{dom_id(@deleted_invoice_paid)}"
    assert_select "tr##{dom_id(@deleted_invoice_pending)}", count: 0
  end

  test "landlord can view invoice details of a deleted house" do
    log_in_as(@landlord_user)
    get landlord_archived_invoice_path(@deleted_invoice_paid)
    assert_response :success
    assert_select ".alert-danger", text: /#{I18n.t("invoice.deleted_house_notice")}/
  end

  test "landlord cannot view active house invoice in archive" do
    log_in_as(@landlord_user)
    get landlord_archived_invoice_path(@active_invoice)
    assert_response :not_found
  end

  test "landlord cannot view another landlord's invoice" do
    log_in_as(@landlord_user)
    get landlord_archived_invoice_path(@other_invoice)
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
