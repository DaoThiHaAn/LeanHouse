require "test_helper"

class LandlordPortal::InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Invoice Master",
      tel: "0906665544",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 32.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Invoice Target",
      tel: "0908889900",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 24.years.ago.to_date,
      address: "456 Tenant St",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @past_tenant_user = User.create!(
      fullname: "Past Checked Out Tenant",
      tel: "0901112233",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 26.years.ago.to_date,
      address: "789 Old St",
      tel_verified_at: Time.current
    )
    @past_tenant = Tenant.find_or_create_by!(id: @past_tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Invoice Controller House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 2,
      inv_creation_date: 1
    )

    @floor1 = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @floor2 = @house.floors.create!(name: "Floor 2", position: 2, rooms_count: 1)
    @room1 = @floor1.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @room2 = @floor2.rooms.create!(name: "Room 201", max_slots: 2, tenants_count: 0, area: 28.0)

    @unit1 = @room1.rental_unit || @room1.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    # Active stay for @tenant
    @unit1.tenant_stays.create!(tenant: @tenant, checkin_at: 1.month.ago, checkout_at: nil)
    # Checked-out stay for @past_tenant
    @unit1.tenant_stays.create!(tenant: @past_tenant, checkin_at: 5.months.ago, checkout_at: 1.month.ago)

    @billing_month = Date.current.beginning_of_month

    @invoice1 = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-101-AAAA",
      title: "Thu tiền tháng này",
      room: @room1,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 3_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_000_000
    )

    @invoice2 = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-201-BBBB",
      title: "Thu tiền cá nhân",
      room: @room1,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 2.days,
      invoice_type: :individual,
      status: :paid,
      subtotal: 1_500_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 1_500_000,
      paid_at: Time.current
    )

    # Cancelled invoice (must not be counted in total)
    @cancelled_invoice = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-101-CANCEL",
      title: "Hóa đơn hủy",
      room: @room1,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :cancelled,
      subtotal: 2_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 2_000_000
    )

    # Invoice for past checked-out tenant
    @past_invoice = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-PAST-CCCC",
      title: "Thu tiền khách cũ",
      room: @room2,
      tenant: @past_tenant,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current - 2.days,
      invoice_type: :individual,
      status: :overdue,
      subtotal: 800_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 800_000
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

  test "landlord can view invoice index with 3 grouped stat cards and tooltip" do
    sign_in_as(@landlord_user)

    get landlord_house_invoices_path(@house)
    assert_response :success

    # Check 3 stat cards exist
    assert_select "div#invoice_stats_grid" do
      assert_select "div.stat-card", 3
      assert_select "div.stat-card-teal" # Card 1: Total invoices
      assert_select "div.stat-card-blue" # Card 2: Grouped financial card
    end

    # Card 1: Tooltip for cancelled invoices
    assert_select "span[data-controller='tooltip'][data-bs-toggle='tooltip'][data-bs-title='#{I18n.t('invoice.stats.cancelled_excluded_tooltip')}']"

    # Month field placeholder
    assert_select "input[type='month'][placeholder='YYYY-MM']"

    # Current tenants only checkbox is present and checked by default
    assert_select "input[type='checkbox'][name='current_tenants_only'][checked='checked']"

    # Floor filter
    assert_select "select#floor_id" do
      assert_select "option", text: I18n.t("invoice.all_floors")
      assert_select "option", text: @floor1.title_name
      assert_select "option", text: @floor2.title_name
    end

    # Optgroup rooms
    assert_select "select#room_id" do
      assert_select "optgroup[label='#{@floor1.title_name}']"
      assert_select "optgroup[label='#{@floor2.title_name}']"
    end

    # Invoice type filter
    assert_select "select#invoice_type" do
      assert_select "option[value='room']", text: I18n.t("invoice.type_room")
      assert_select "option[value='individual']", text: I18n.t("invoice.type_individual")
    end

    # By default, active tenant invoices are shown, past checked-out tenant is excluded
    assert_includes response.body, @invoice1.code
    assert_includes response.body, @invoice2.code
    assert_not_includes response.body, @past_invoice.code
  end

  test "unchecking current_tenants_only displays all invoices including past tenants" do
    sign_in_as(@landlord_user)

    # When unchecked (current_tenants_only: "0")
    get filtered_landlord_house_invoices_path(@house, current_tenants_only: "0")
    assert_response :success
    assert_includes response.body, @invoice1.code
    assert_includes response.body, @invoice2.code
    assert_includes response.body, @past_invoice.code
  end

  test "landlord can filter by invoice_type" do
    sign_in_as(@landlord_user)

    # Filter room invoices only
    get filtered_landlord_house_invoices_path(@house, invoice_type: "room")
    assert_response :success
    assert_includes response.body, @invoice1.code
    assert_not_includes response.body, @invoice2.code

    # Filter individual invoices only
    get filtered_landlord_house_invoices_path(@house, invoice_type: "individual")
    assert_response :success
    assert_not_includes response.body, @invoice1.code
    assert_includes response.body, @invoice2.code
  end

  test "landlord can filter by floor_id" do
    sign_in_as(@landlord_user)

    # Filter floor 1 only
    get filtered_landlord_house_invoices_path(@house, floor_id: @floor1.id)
    assert_response :success
    assert_includes response.body, @invoice1.code
    assert_includes response.body, @invoice2.code

    # Filter floor 2 only
    get filtered_landlord_house_invoices_path(@house, floor_id: @floor2.id)
    assert_response :success
    assert_not_includes response.body, @invoice1.code
    assert_not_includes response.body, @invoice2.code
  end

  test "landlord can filter by status and stats update dynamically" do
    sign_in_as(@landlord_user)

    # Filter pending
    get filtered_landlord_house_invoices_path(@house, status: "pending")
    assert_response :success
    assert_includes response.body, @invoice1.code
    assert_not_includes response.body, @invoice2.code

    # Filter paid
    get filtered_landlord_house_invoices_path(@house, status: "paid")
    assert_response :success
    assert_not_includes response.body, @invoice1.code
    assert_includes response.body, @invoice2.code
  end

  test "checkbox state matches current_tenants_only param" do
    sign_in_as(@landlord_user)

    # When current_tenants_only=0
    get landlord_house_invoices_path(@house, current_tenants_only: "0")
    assert_response :success
    assert_select "input[type='checkbox'][name='current_tenants_only']:not([checked])"

    # When current_tenants_only=1
    get landlord_house_invoices_path(@house, current_tenants_only: "1")
    assert_response :success
    assert_select "input[type='checkbox'][name='current_tenants_only'][checked='checked']"

    # When current_tenants_only is absent (default)
    get landlord_house_invoices_path(@house)
    assert_response :success
    assert_select "input[type='checkbox'][name='current_tenants_only'][checked='checked']"
  end

  test "invoices index includes pagination-sync controller for url synchronization" do
    sign_in_as(@landlord_user)

    get landlord_house_invoices_path(@house)
    assert_response :success

    # Check turbo frame has pagination-sync controller and canonical URL
    assert_select "turbo-frame#invoices_content[data-controller~='pagination-sync']" do
      assert_select "[data-pagination-sync-canonical-url-value='#{landlord_house_invoices_path(@house)}']"
      assert_select "[data-pagination-sync-total-pages-selector-value='[data-pagination-total-pages]']"
    end

    # Check form has turbo_action: advance
    assert_select "form[data-turbo-action='advance']"

    # Check total pages marker exists
    assert_select "span[data-pagination-total-pages]"
  end

  test "invoices are paginated to 15 per page and stats calculate for all records" do
    sign_in_as(@landlord_user)

    # Create 16 more room invoices for @room1 in this month so total is 18 invoices
    16.times do |i|
      @house.invoices.create!(
        room: @room1,
        created_by: @landlord_user,
        title: "Hóa đơn phân trang #{i + 1}",
        invoice_type: "room",
        billing_month: @billing_month,
        due_date: @billing_month + 10.days,
        start_date: @billing_month,
        end_date: @billing_month.end_of_month,
        status: :pending,
        subtotal: 100_000,
        total_discount: 0,
        total_addition: 0,
        total_amount: 100_000,
        code: "INV-PAG-#{i + 1}"
      )
    end

    # Total valid invoices for this month = 1 (@invoice1) + 1 (@invoice2) + 16 = 18 invoices
    get landlord_house_invoices_path(@house)
    assert_response :success

    # Check stats cards calculate for all 18 invoices (not just the 15 on page 1)
    assert_select "div.stat-card-teal" do
      assert_select ".stat-card-value", text: "18"
    end

    # Page 1 displays 15 invoices
    assert_select "table.invoice-table tbody tr", 15

    # Pagination controls exist (2 total pages)
    assert_select "span[data-pagination-total-pages='2']"
    assert_select "nav.pagination"

    # Page 2 displays remaining 4 invoices (18 valid + 1 cancelled = 19 total)
    get filtered_landlord_house_invoices_path(@house, page: 2)
    assert_response :success
    assert_select "table.invoice-table tbody tr", 4

    # On page 2, stats still calculate for all 18 invoices
    assert_select "div.stat-card-teal" do
      assert_select ".stat-card-value", text: "18"
    end
  end

  test "landlord can load invoice edit modal and modify non-price fields" do
    sign_in_as(@landlord_user)

    get edit_landlord_house_invoice_path(@house, @invoice1)
    assert_response :success

    assert_select "turbo-frame#edit_invoice_modal" do
      assert_select "div#editInvoiceModal[data-controller='modal']"
      assert_select "input[name='invoice[title]'][value='#{@invoice1.title}']"
      assert_select "input[name='invoice[due_date]']"
      assert_select "input[name='invoice[start_date]']"
      assert_select "input[name='invoice[end_date]']"
      assert_select "select[name='invoice[bank_account_id]']"
      assert_select "textarea[name='invoice[note]']"
      # No price input fields
      assert_select "input[name='invoice[subtotal]']", 0
      assert_select "input[name='invoice[total_amount]']", 0
    end
  end

  test "landlord can update invoice via turbo_stream updating only the affected row" do
    sign_in_as(@landlord_user)

    new_due_date = Date.current + 12.days
    patch landlord_house_invoice_path(@house, @invoice1),
          params: {
            invoice: {
              title: "Tiền phòng cập nhật mới",
              due_date: new_due_date,
              note: "Ghi chú đã sửa"
            }
          },
          as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_includes response.body, %(action="replace" target="#{ActionView::RecordIdentifier.dom_id(@invoice1)}")
    assert_includes response.body, new_due_date.strftime("%d/%m/%Y")
    assert_includes response.body, "Tiền phòng cập nhật mới"
    assert_includes response.body, %(action="append" target="events")
    assert_includes response.body, "close-modal"
    assert_includes response.body, %(action="update" target="flash")

    # Verifies database is updated
    @invoice1.reload
    assert_equal "Tiền phòng cập nhật mới", @invoice1.title
    assert_equal new_due_date, @invoice1.due_date
    assert_equal "Ghi chú đã sửa", @invoice1.note
  end
end
