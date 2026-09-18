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

  test "landlord can view new invoice page with character counters for title and note and required indicators" do
    sign_in_as(@landlord_user)

    get new_landlord_house_invoice_path(@house)
    assert_response :success

    assert_select ".invoice-card .card-header", text: /#{I18n.t('general_info')}/
    assert_select "label .text-danger", text: "*", count: 5
    assert_select "select#tenant_select", count: 0
    assert_select "div#individual_split_notice"

    assert_select "div[data-controller='character-counter'][data-character-counter-max-value='100']" do
      assert_select "span[data-character-counter-target='count']"
      assert_select "input[name='invoice[title]'][data-character-counter-target='input'][maxlength='100']"
    end

    assert_select "form[data-controller~='loading'][data-action~='submit->loading#submit']"
    assert_select "button[type='submit'][data-loading-target='button']" do
      assert_select "span[data-loading-target='text']", text: I18n.t("invoice.issue_button")
      assert_select "span[data-loading-target='spinner']", text: "progress_activity"
    end
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

    # Floor filter
    assert_select "select#floor_id" do
      assert_select "option", text: I18n.t("invoice.all_floors")
      assert_select "option", text: @floor1.title_name
      assert_select "option", text: @floor2.title_name
    end

    # Cascading rooms select
    assert_select "select#room_id" do
      assert_select "option", text: @room1.title_name
      assert_select "option", text: @room2.title_name
    end

    # Invoice type / payment mode filter
    assert_select "select#invoice_type" do
      assert_select "option[value='room']", text: I18n.t("invoice.mode_representative")
      assert_select "option[value='individual']", text: I18n.t("invoice.mode_self_pay")
    end

    # By default, all invoices for the month are shown including past tenants
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

    # Check stats cards calculate for all 19 invoices in monthly overview (not just the 15 on page 1)
    assert_select "div.stat-card-teal" do
      assert_select ".stat-card-value", text: "19"
    end

    # Page 1 displays 15 invoices
    assert_select "table.invoice-table tbody tr", 15

    # Pagination controls exist (2 total pages)
    assert_select "span[data-pagination-total-pages='2']"
    assert_select "nav.pagination"

    # Page 2 displays remaining 5 invoices (19 valid + 1 cancelled = 20 total)
    get filtered_landlord_house_invoices_path(@house, page: 2)
    assert_response :success
    assert_select "table.invoice-table tbody tr", 5

    # On page 2, stats still calculate for all 19 invoices in monthly overview
    assert_select "div.stat-card-teal" do
      assert_select ".stat-card-value", text: "19"
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

  test "landlord can update invoice transfer_note to custom or none" do
    sign_in_as(@landlord_user)

    # 1. Update to custom note
    patch landlord_house_invoice_path(@house, @invoice1),
          params: {
            invoice: {
              transfer_note_mode: "custom",
              transfer_note: "TIEN PHONG P101 THANG 9"
            }
          }
    assert_redirected_to landlord_house_invoice_path(@house, @invoice1)
    assert_equal "TIEN PHONG P101 THANG 9", @invoice1.reload.transfer_note

    # 2. Update to none
    patch landlord_house_invoice_path(@house, @invoice1),
          params: {
            invoice: {
              transfer_note_mode: "none"
            }
          }
    assert_redirected_to landlord_house_invoice_path(@house, @invoice1)
    assert_nil @invoice1.reload.transfer_note

    # 3. Update to system
    patch landlord_house_invoice_path(@house, @invoice1),
          params: {
            invoice: {
              transfer_note_mode: "system"
            }
          }
    assert_redirected_to landlord_house_invoice_path(@house, @invoice1)
    assert_equal @invoice1.code, @invoice1.reload.transfer_note
  end

  test "landlord can mark invoice as paid with optional proof and payment method" do
    sign_in_as(@landlord_user)

    file = fixture_file_upload("normal.png", "image/png")

    assert_emails 0 do
      patch mark_paid_landlord_house_invoice_path(@house, @invoice1),
            params: {
              payment_method: "transfer",
              payment_proof: file,
              note: "Khách đã chuyển khoản thành công"
            }
    end

    assert_redirected_to landlord_house_invoice_path(@house, @invoice1)
    follow_redirect!
    assert_includes response.body, "Đã xác nhận thanh toán hóa đơn #{@invoice1.code}!"

    @invoice1.reload
    assert_predicate @invoice1, :paid?
    assert_equal "transfer", @invoice1.payment_method
    assert_equal @landlord_user.id, @invoice1.paid_by_id
    assert_equal "landlord", @invoice1.paid_by_role
    assert_not_nil @invoice1.paid_at
    assert_predicate @invoice1.payment_proof, :attached?
    assert_includes @invoice1.note, "Khách đã chuyển khoản thành công"

    # Verifies landlord show page shows payment proof thumbnail
    assert_select ".payment-proof-thumb"
    assert_select "[data-bs-target='#viewPaymentProofModal']"
  end

  test "paid invoice without attached proof shows no image fallback text" do
    sign_in_as(@landlord_user)

    # @invoice2 is paid without attached proof
    assert_predicate @invoice2, :paid?
    assert_not_predicate @invoice2.payment_proof, :attached?

    get landlord_house_invoice_path(@house, @invoice2)
    assert_response :success
    assert_select ".payment-proof-thumb", 0
    assert_includes response.body, I18n.t("invoice.no_payment_proof")
  end

  test "landlord can undo paid invoice with mandatory explanation" do
    sign_in_as(@landlord_user)

    # @invoice2 is initially paid
    assert_predicate @invoice2, :paid?
    assert_equal "transfer", @invoice2.payment_method

    patch undo_paid_landlord_house_invoice_path(@house, @invoice2),
          params: {
            explanation: "Chưa nhận được tiền vào tài khoản Techcombank"
          }

    assert_redirected_to landlord_house_invoice_path(@house, @invoice2)
    follow_redirect!
    assert_includes response.body, "Đã hủy xác nhận thanh toán cho hóa đơn #{@invoice2.code}!"

    @invoice2.reload
    assert_not_predicate @invoice2, :paid?
    assert_nil @invoice2.paid_at
    assert_nil @invoice2.payment_method
    assert_equal "Chưa nhận được tiền vào tài khoản Techcombank", @invoice2.undo_reason
    assert_equal @landlord_user.id, @invoice2.undone_by_id
    assert_includes @invoice2.note, "Hủy xác nhận thanh toán bởi #{@landlord_user.fullname}"
  end

  test "landlord cannot undo paid invoice without explanation" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice2, :paid?

    patch undo_paid_landlord_house_invoice_path(@house, @invoice2),
          params: {
            explanation: ""
          }

    assert_redirected_to landlord_house_invoice_path(@house, @invoice2)
    follow_redirect!
    assert_includes response.body, I18n.t("invoice.errors.explanation_required", default: "Vui lòng nhập lý do hủy xác nhận thanh toán.")

    @invoice2.reload
    assert_predicate @invoice2, :paid?
    assert_not_nil @invoice2.payment_method
  end

  test "when landlord undoes payment on room invoice with multiple tenants, all tenants receive unpay notification" do
    sign_in_as(@landlord_user)

    bed_house = House.create!(
      landlord: @landlord,
      name: "Dorm House 2",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = bed_house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 301", max_slots: 2, tenants_count: 2, area: 30.0)
    bed1 = room.beds.create!(name: "Bed A")
    bed2 = room.beds.create!(name: "Bed B")
    ru1 = bed1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    ru2 = bed2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    u1 = User.create!(fullname: "Tenant Mot", tel: "0911112233", password: "Password123", password_confirmation: "Password123", role: "tenant", sex: "male", bday: 22.years.ago.to_date, address: "St 1", tel_verified_at: Time.current)
    u2 = User.create!(fullname: "Tenant Hai", tel: "0911112244", password: "Password123", password_confirmation: "Password123", role: "tenant", sex: "male", bday: 23.years.ago.to_date, address: "St 2", tel_verified_at: Time.current)
    t1 = Tenant.find_or_create_by!(id: u1.id)
    t2 = Tenant.find_or_create_by!(id: u2.id)

    TenantStay.create!(rental_unit: ru1, tenant: t1, checkin_at: 1.month.ago)
    TenantStay.create!(rental_unit: ru2, tenant: t2, checkin_at: 1.month.ago)

    room_inv = bed_house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-301-ROOM",
      title: "Tiền phòng 301",
      room: room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :paid,
      paid_at: Time.current,
      payment_method: "transfer",
      subtotal: 1_000_000,
      total_amount: 1_000_000
    )

    assert_difference -> { Noticed::Notification.count }, 3 do # Landlord + Tenant 1 + Tenant 2
      patch undo_paid_landlord_house_invoice_path(bed_house, room_inv),
            params: { explanation: "Chưa đối soát được tài khoản" }
    end

    t1_noti = u1.notifications.last
    assert_includes t1_noti.message, "Chưa đối soát được tài khoản"
    assert_includes t1_noti.message, "Room 301"

    t2_noti = u2.notifications.last
    assert_includes t2_noti.message, "Chưa đối soát được tài khoản"
    assert_includes t2_noti.message, "Room 301"
  end

  test "new invoice form renders two separate cards with floor dropdown and empty room prompt by default" do
    sign_in_as(@landlord_user)

    get new_landlord_house_invoice_path(@house)
    assert_response :success

    # Two distinct cards: General Info & Target Scope
    assert_select "h2", text: /#{I18n.t('general_info')}/
    assert_select "h2", text: /#{I18n.t('invoice.target_scope')}/

    # Floor dropdown is present
    assert_select "select#floor_select" do
      assert_select "option[value='']", text: I18n.t("invoice.all_floors_option")
      assert_select "option[value='#{@floor1.id}']", text: @floor1.title_name
    end

    # Room dropdown only lists occupied rooms (@room1), NOT vacant rooms (@room2)
    assert_select "select#room_select" do
      assert_select "option[value='#{@room1.id}']"
      assert_select "option[value='#{@room2.id}']", 0
    end

    # By default without room_id, prompt asking to select room first is displayed
    assert_select "h5", text: I18n.t("invoice.select_room_first_title")
    assert_select "p", text: I18n.t("invoice.select_room_first_desc")
    assert_select "table#invoice_items_table", 0

    # Billing month tooltip info icon
    assert_select "span.material-symbols-outlined[data-controller='tooltip'][data-bs-toggle='tooltip']", text: "info"
  end

  test "new invoice form with preselected occupied room renders draft items with rent row" do
    sign_in_as(@landlord_user)

    get new_landlord_house_invoice_path(@house, room_id: @room1.id)
    assert_response :success

    # Draft items table is rendered
    assert_select "table#invoice_items_table" do
      # Rent row
      assert_select "tr[data-item-type='rent']" do
        assert_select "input[type='checkbox'].item-select-check[checked]"
        assert_select "input.item-name[readonly='readonly']"
        assert_select "input.item-price[readonly='readonly']"
        assert_select "span.badge", text: I18n.t("invoice.rent_unit_month")
        assert_select "input.item-qty[min='1']"
      end
    end
  end

  test "preview endpoint returns empty prompt when room_id is blank, and draft items when room_id is present" do
    sign_in_as(@landlord_user)

    # Empty room_id preview
    get preview_landlord_house_invoices_path(@house, room_id: "")
    assert_response :success
    assert_select "h5", text: I18n.t("invoice.select_room_first_title")
    assert_select "table#invoice_items_table", 0

    # With room_id preview
    get preview_landlord_house_invoices_path(@house, room_id: @room1.id)
    assert_response :success
    assert_select "table#invoice_items_table"
    assert_select "tbody#addition_items_container[data-invoice-items-target='additionContainer']"
    assert_select "tbody#discount_items_container[data-invoice-items-target='discountContainer']"
  end

  test "preview endpoint renders standard applied services with readonly unit price and unit badge" do
    sign_in_as(@landlord_user)

    service1 = @house.services.create!(name: "Dịch vụ Internet")
    variant1 = service1.service_variants.create!(fee: 100_000, unit: :per_room, is_real_time: false)
    @room1.room_services.create!(service_variant: variant1)

    get preview_landlord_house_invoices_path(@house, room_id: @room1.id, invoice_type: "room")
    assert_response :success
    assert_select "table#invoice_items_table"
    assert_select "tbody#standard_items_tbody tr.standard-row input.item-price[readonly='readonly']"
    assert_select "tbody#standard_items_tbody tr.standard-row span.item-price-badge" do |elements|
      assert_match(/100,000 đ/, elements.text)
    end
    assert_select "tbody#standard_items_tbody tr.standard-row input.item-amount[type='hidden']"
    assert_select "tbody#standard_items_tbody tr.standard-row span.item-amount-display" do |elements|
      assert_match(/100,000 đ/, elements.text)
    end
    assert_select "tbody#standard_items_tbody tr.standard-row input.item-name[readonly='readonly']"
    assert_select "tbody#standard_items_tbody tr.standard-row select.item-unit", 0
    assert_select "tbody#standard_items_tbody tr.standard-row input.item-unit[type='hidden']"
    assert_select "tbody#standard_items_tbody tr.standard-row input.item-select-check"
  end

  test "individual invoice for room-mode room divides rent equally among staying tenants" do
    # When 2 active occupants are in @room1
    @room1.update!(tenants_count: 2)

    calculator = Invoices::DraftCalculator.new(
      room: @room1,
      billing_month: @billing_month,
      invoice_type: "individual",
      tenant: @tenant
    )
    items = calculator.build_items
    rent_item = items.find { |i| i[:item_type] == :rent }

    assert_not_nil rent_item
    # Total rent is 3,000,000, 2 active occupants -> 1,500,000
    assert_equal 1_500_000, rent_item[:unit_price]
    assert_equal 1_500_000, rent_item[:amount]
    assert_equal "tháng", rent_item[:unit]
  end

  test "submitting create without room returns unprocessable entity with alert" do
    sign_in_as(@landlord_user)

    post landlord_house_invoices_path(@house),
         params: {
           invoice: {
             title: "Hóa đơn test",
             billing_month: @billing_month.strftime("%Y-%m"),
             room_id: ""
           }
         }

    assert_response :unprocessable_entity
    assert_includes flash[:alert], I18n.t("invoice.select_room_prompt")
  end

  test "landlord visiting edit on a paid invoice is redirected with alert" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice2, :paid?

    get edit_landlord_house_invoice_path(@house, @invoice2)
    assert_redirected_to landlord_house_invoice_path(@house, @invoice2)
    follow_redirect!
    assert_includes response.body, I18n.t("invoice.errors.cannot_update_paid")
  end

  test "landlord updating a paid invoice via turbo_stream is rejected with alert" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice2, :paid?

    patch landlord_house_invoice_path(@house, @invoice2),
          params: {
            invoice: {
              title: "Cố tình sửa khi đã thanh toán"
            }
          },
          as: :turbo_stream

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("invoice.errors.cannot_update_paid")

    @invoice2.reload
    assert_not_equal "Cố tình sửa khi đã thanh toán", @invoice2.title
  end

  test "landlord updating a paid invoice via html is redirected with alert" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice2, :paid?

    patch landlord_house_invoice_path(@house, @invoice2),
          params: {
            invoice: {
              title: "Cố tình sửa khi đã thanh toán"
            }
          }

    assert_redirected_to landlord_house_invoice_path(@house, @invoice2)
    follow_redirect!
    assert_includes response.body, I18n.t("invoice.errors.cannot_update_paid")

    @invoice2.reload
    assert_not_equal "Cố tình sửa khi đã thanh toán", @invoice2.title
  end

  test "landlord cannot cancel a paid invoice and is redirected with alert" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice2, :paid?

    patch cancel_landlord_house_invoice_path(@house, @invoice2)
    assert_redirected_to landlord_house_invoice_path(@house, @invoice2)
    follow_redirect!
    assert_includes response.body, I18n.t("invoice.errors.cannot_cancel_paid")

    @invoice2.reload
    assert_predicate @invoice2, :paid?
  end

  test "paid invoice show page does not render edit button or edit modal, but renders undo paid button" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice2, :paid?

    get landlord_house_invoice_path(@house, @invoice2)
    assert_response :success

    # Edit button / link and edit modal are NOT present
    assert_select "a[href*='#{edit_landlord_house_invoice_path(@house, @invoice2)}']", 0
    assert_select "#editInvoiceModal", 0

    # Undo payment button and modal ARE present
    assert_select "button[data-bs-target='#undoPaidModal']"
    assert_select "#undoPaidModal"
  end

  test "pending invoice show page renders edit link targeting turbo frame and turbo_frame_tag" do
    sign_in_as(@landlord_user)

    assert_predicate @invoice1, :pending?

    get landlord_house_invoice_path(@house, @invoice1)
    assert_response :success

    assert_select "a[href*='#{edit_landlord_house_invoice_path(@house, @invoice1)}'][data-turbo-frame='edit_invoice_modal']"
    assert_select "turbo-frame#edit_invoice_modal"
  end

  test "landlord updating invoice with return_to show redirects to invoice show page" do
    sign_in_as(@landlord_user)

    new_due_date = Date.current + 15.days
    patch landlord_house_invoice_path(@house, @invoice1),
          params: {
            return_to: "show",
            invoice: {
              title: "Sửa từ trang show",
              due_date: new_due_date
            }
          }

    assert_redirected_to landlord_house_invoice_path(@house, @invoice1)
    follow_redirect!
    assert_includes response.body, I18n.t("invoice.update_success")
    assert_equal "Sửa từ trang show", @invoice1.reload.title
  end

  test "invoices index renders new invoice dropdown with standard and custom fee options" do
    sign_in_as(@landlord_user)

    get landlord_house_invoices_path(@house)
    assert_response :success

    assert_select ".dropdown .dropdown-toggle", text: /#{I18n.t('invoice.new_invoice')}/
    assert_select "a[href*='new_custom']"
  end

  test "GET new_custom renders custom invoice form and lists staying tenants" do
    sign_in_as(@landlord_user)

    get new_custom_landlord_house_invoices_path(@house)
    assert_response :success

    assert_select "input[name='mode'][value='custom']"
    assert_select "input[name='invoice[tenant_ids][]'][value='#{@tenant.id}']"
    assert_select "table#custom_invoice_items_table"
    assert_select "tbody#custom_addition_items_container[data-invoice-items-target='additionContainer']"
    assert_select "tbody#custom_discount_items_container[data-invoice-items-target='discountContainer']"
  end

  test "GET new with mode: custom renders custom invoice form and lists staying tenants" do
    sign_in_as(@landlord_user)

    get new_landlord_house_invoice_path(@house, mode: "custom")
    assert_response :success

    assert_select "input[name='mode'][value='custom']"
    assert_select "input[name='invoice[tenant_ids][]'][value='#{@tenant.id}']"
    assert_select "table#custom_invoice_items_table"
  end

  test "POST create with mode: custom successfully creates invoices for multiple selected tenants" do
    sign_in_as(@landlord_user)

    # Create a second staying tenant in Room 201
    tenant_user2 = User.create!(
      fullname: "Second Staying Tenant",
      tel: "0907778899",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "222 Tenant St",
      tel_verified_at: Time.current
    )
    tenant2 = Tenant.find_or_create_by!(id: tenant_user2.id)
    unit2 = @room2.rental_unit || @room2.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)
    unit2.tenant_stays.create!(tenant: tenant2, checkin_at: 2.months.ago, checkout_at: nil)

    assert_difference -> { Invoice.count } => 2, -> { InvoiceItem.count } => 2 do
      post landlord_house_invoices_path(@house), params: {
        mode: "custom",
        invoice: {
          billing_month: @billing_month.strftime("%Y-%m"),
          title: "Phí vệ sinh hành lang",
          due_date: (Date.current + 5.days).to_s,
          tenant_ids: [ @tenant.id, tenant2.id ],
          items: {
            "0" => {
              selected: "1",
              item_type: "addition",
              name: "Phụ phí vệ sinh",
              unit: "lần",
              unit_price: "50000",
              quantity: "1",
              amount: "50000"
            }
          }
        }
      }
    end

    assert_redirected_to landlord_house_invoices_path(@house, month: @billing_month.strftime("%Y-%m"), tab: "individual")
    follow_redirect!
    assert_includes response.body, "Đã xuất thành công 2 hóa đơn"
  end

  test "POST create with mode: custom fails and re-renders new with 422 when no tenants selected" do
    sign_in_as(@landlord_user)

    assert_no_difference "Invoice.count" do
      post landlord_house_invoices_path(@house), params: {
        mode: "custom",
        invoice: {
          billing_month: @billing_month.strftime("%Y-%m"),
          title: "Phí vệ sinh",
          tenant_ids: [],
          items: {
            "0" => {
              selected: "1",
              item_type: "addition",
              name: "Phụ phí",
              unit_price: "50000",
              quantity: "1",
              amount: "50000"
            }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("invoice.errors.no_tenants_selected")
  end

  test "POST create_custom successfully creates custom invoices using dedicated route" do
    sign_in_as(@landlord_user)

    assert_difference -> { Invoice.count } => 1, -> { InvoiceItem.count } => 1 do
      post create_custom_landlord_house_invoices_path(@house), params: {
        invoice: {
          billing_month: @billing_month.strftime("%Y-%m"),
          title: "Phí vệ sinh hành lang riêng",
          due_date: (Date.current + 5.days).to_s,
          tenant_ids: [ @tenant.id ],
          items: {
            "0" => {
              selected: "1",
              item_type: "addition",
              name: "Phụ phí vệ sinh",
              unit: "lần",
              unit_price: "60000",
              quantity: "1",
              amount: "60000"
            }
          }
        }
      }
    end

    created_invoice = Invoice.order(:created_at).last
    assert_redirected_to landlord_house_invoice_path(@house, created_invoice)
    assert_equal "Phí vệ sinh hành lang riêng", created_invoice.title
    assert_equal 60_000, created_invoice.total_amount
  end

  test "tab switching between room invoices and custom individual invoices" do
    sign_in_as(@landlord_user)

    custom_inv = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-CUSTOM-001",
      title: "Thu phí xe máy ngoài giờ",
      room: @room1,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 3.days,
      invoice_type: :custom,
      status: :pending,
      subtotal: 150_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 150_000
    )

    # 1. Room tab (default): shows @invoice1 and @invoice2, does NOT show custom_inv
    get landlord_house_invoices_path(@house, tab: "room")
    assert_response :success
    assert_includes response.body, @invoice1.code
    assert_not_includes response.body, custom_inv.code

    # Tab count badges
    assert_select "a.log-tab.active" do
      assert_select "span.badge", text: "4" # @invoice1, @invoice2, @cancelled_invoice, @past_invoice
    end
    assert_select "a.log-tab:not(.active)" do
      assert_select "span.badge", text: "1" # custom_inv
    end

    # 2. Individual / Custom tab: shows custom_inv, does NOT show @invoice1
    get landlord_house_invoices_path(@house, tab: "individual")
    assert_response :success
    assert_includes response.body, custom_inv.code
    assert_not_includes response.body, @invoice1.code
    assert_select "a.log-tab.active" do
      assert_select "span.badge", text: "1"
    end
  end

  test "search by tenant fullname and tel in custom individual tab" do
    sign_in_as(@landlord_user)

    custom_inv1 = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-CUSTOM-AAA",
      title: "Thu tiền giặt ủi",
      room: @room1,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 3.days,
      invoice_type: :custom,
      status: :pending,
      subtotal: 100_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 100_000
    )

    custom_inv2 = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-CUSTOM-BBB",
      title: "Thu phí đỗ xe",
      room: @room2,
      tenant: @past_tenant,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 3.days,
      invoice_type: :custom,
      status: :pending,
      subtotal: 200_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 200_000
    )

    # Search by tenant fullname
    get filtered_landlord_house_invoices_path(@house, tab: "individual", q: "Tenant Invoice Target")
    assert_response :success
    assert_includes response.body, custom_inv1.code
    assert_not_includes response.body, custom_inv2.code

    # Search by tenant phone number
    get filtered_landlord_house_invoices_path(@house, tab: "individual", q: "0901112233")
    assert_response :success
    assert_includes response.body, custom_inv2.code
    assert_not_includes response.body, custom_inv1.code
  end

  test "monthly overview stats remain stable and decoupled from table filters" do
    sign_in_as(@landlord_user)

    # Filter table by status=paid
    get filtered_landlord_house_invoices_path(@house, tab: "room", status: "paid")
    assert_response :success

    # Invoices table only displays paid invoice (@invoice2)
    assert_includes response.body, @invoice2.code
    assert_not_includes response.body, @invoice1.code

    # Stats cards still show total 3 invoices (monthly overview is decoupled from status filter)
    assert_select "div.stat-card-teal" do
      assert_select ".stat-card-value", text: "3"
    end

    # Overview badge and tooltip are displayed on the dashboard
    assert_select "span[data-bs-title='#{I18n.t('invoice.stats.monthly_overview_hint')}']", text: /#{I18n.t('invoice.stats.monthly_overview_badge')}/
  end

  test "payment_mode filter in room tab separates room representative and individual self pay" do
    sign_in_as(@landlord_user)

    # Filter payment_mode: room
    get filtered_landlord_house_invoices_path(@house, tab: "room", invoice_type: "room")
    assert_response :success
    assert_includes response.body, @invoice1.code
    assert_not_includes response.body, @invoice2.code

    # Filter payment_mode: individual
    get filtered_landlord_house_invoices_path(@house, tab: "room", invoice_type: "individual")
    assert_response :success
    assert_includes response.body, @invoice2.code
    assert_not_includes response.body, @invoice1.code
  end

  test "creating room invoice ignores tenant_id and invoice show displays representative info" do
    sign_in_as(@landlord_user)

    assert_difference -> { @house.invoices.count }, 1 do
      post landlord_house_invoices_path(@house), params: {
        invoice: {
          room_id: @room1.id,
          invoice_type: "room",
          tenant_id: @tenant.id,
          billing_month: @billing_month.strftime("%Y-%m"),
          due_date: Date.current + 5.days,
          title: "Hóa đơn phòng 101",
          items: [
            {
              selected: "1",
              item_type: "rent",
              name: "Tiền phòng",
              unit: "tháng",
              unit_price: 3_000_000,
              quantity: 1,
              amount: 3_000_000
            }
          ]
        }
      }
    end

    created_invoice = Invoice.order(:created_at).last
    assert_redirected_to landlord_house_invoice_path(@house, created_invoice)
    assert_nil created_invoice.tenant_id
    assert_predicate created_invoice, :room?

    follow_redirect!
    assert_response :success
    # Should display representative room mode, and not attribute the bill to the single tenant
    assert_includes response.body, I18n.t("invoice.room_occupants_notice")
    assert_includes response.body, I18n.t("invoice.badge_representative")
  end

  test "creating individual invoice creates separate equally-divided invoices for all staying tenants in room without tenant_id" do
    sign_in_as(@landlord_user)

    bed_house = House.create!(
      landlord: @landlord,
      name: "Dorm House Test",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = bed_house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 301", max_slots: 2, tenants_count: 2, area: 30.0)
    bed1 = room.beds.create!(name: "Bed A")
    bed2 = room.beds.create!(name: "Bed B")
    ru1 = bed1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    ru2 = bed2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    u1 = User.create!(fullname: "Tenant Mot", tel: "0911112233", password: "Password123", password_confirmation: "Password123", role: "tenant", sex: "male", bday: 22.years.ago.to_date, address: "St 1", tel_verified_at: Time.current)
    u2 = User.create!(fullname: "Tenant Hai", tel: "0911112244", password: "Password123", password_confirmation: "Password123", role: "tenant", sex: "male", bday: 23.years.ago.to_date, address: "St 2", tel_verified_at: Time.current)
    t1 = Tenant.find_or_create_by!(id: u1.id)
    t2 = Tenant.find_or_create_by!(id: u2.id)

    TenantStay.create!(rental_unit: ru1, tenant: t1, checkin_at: 1.month.ago)
    TenantStay.create!(rental_unit: ru2, tenant: t2, checkin_at: 1.month.ago)

    assert_difference -> { bed_house.invoices.count }, 2 do
      post landlord_house_invoices_path(bed_house), params: {
        invoice: {
          room_id: room.id,
          invoice_type: "individual",
          billing_month: @billing_month.strftime("%Y-%m"),
          due_date: Date.current + 5.days,
          title: "Hóa đơn chia đều phòng 301",
          items: [
            {
              selected: "1",
              item_type: "rent",
              name: "Tiền phòng",
              unit: "tháng",
              unit_price: 1_500_000,
              quantity: 1,
              amount: 1_500_000
            }
          ]
        }
      }
    end

    assert_redirected_to landlord_house_invoices_path(bed_house, month: @billing_month.strftime("%Y-%m"), tab: "room")
    follow_redirect!
    assert_response :success
    assert_includes response.body, I18n.t("invoice.individual_create_success_multiple", count: 2, room: room.title_name)

    created_invoices = bed_house.invoices.order(:created_at).last(2)
    assert_equal 2, created_invoices.size
    created_invoices.each do |inv|
      assert_predicate inv, :individual?
      assert_includes [ t1.id, t2.id ], inv.tenant_id
      assert_equal 1_500_000, inv.total_amount
    end
    assert_equal [ t1.id, t2.id ].sort, created_invoices.map(&:tenant_id).sort
  end

  test "creating individual invoice for room with no staying tenants fails and displays alert" do
    sign_in_as(@landlord_user)

    assert_no_difference -> { @house.invoices.count } do
      post landlord_house_invoices_path(@house), params: {
        invoice: {
          room_id: @room2.id,
          invoice_type: "individual",
          billing_month: @billing_month.strftime("%Y-%m"),
          due_date: Date.current + 5.days,
          title: "Hóa đơn cá nhân phòng trống",
          items: []
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("invoice.errors.no_staying_tenants_in_room")
  end

  test "landlord invoice show renders service instructions modal and trigger button when invoice has services" do
    sign_in_as(@landlord_user)
    @invoice1.invoice_items.create!(
      item_type: "metered_service",
      name: "Điện",
      unit: "kWh",
      unit_price: 3_500,
      quantity: 50,
      amount: 175_000,
      prev_reading: 100,
      latest_reading: 150
    )

    get landlord_house_invoice_path(@house, @invoice1)
    assert_response :success
    assert_includes response.body, 'data-bs-target="#serviceInstructionsModal"'
    assert_includes response.body, 'id="serviceInstructionsModal"'
    assert_includes response.body, CGI.escapeHTML(I18n.t("invoice.service_instructions"))
  end

  test "room-type invoice row does not display tel in room column, while individual/custom displays tenant and tel" do
    sign_in_as(@landlord_user)

    # Attach tenant to room invoice to test that tel is still NOT rendered for room type
    @invoice1.update!(tenant: @tenant)

    # In room tab, both room-type (@invoice1) and individual-type (@invoice2) are rendered
    get filtered_landlord_house_invoices_path(@house, tab: "room")
    assert_response :success

    # Row for @invoice1 (room invoice): Room & floor shown, NO tel
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@invoice1)}" do
      assert_select "td", text: /#{@room1.title_name}/
      assert_select "small.font-monospace", text: @tenant_user.tel, count: 0
    end

    # Row for @invoice2 (individual invoice with tenant): tenant fullname and tel ARE shown
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@invoice2)}" do
      assert_select "div.fw-semibold", text: @tenant_user.fullname
      assert_select "small.font-monospace", text: @tenant_user.tel
    end
  end

  test "invoice show renders payos checkout button and dynamic VietQR when payos is configured" do
    sign_in_as(@landlord_user)
    bank = Bank.find_or_create_by!(code: "MB") do |b|
      b.name = "Military Bank"
      b.short_name = "MB"
      b.bin = "970422"
    end
    bank_account = @landlord.bank_accounts.create!(
      bank: bank,
      account_number: "987654321",
      account_holder: "LANDLORD USER",
      payos_enabled: true,
      payos_client_id: "test-client-id",
      payos_api_key: "test-api-key",
      payos_checksum_key: "test-checksum-key"
    )
    @invoice1.update!(bank_account: bank_account)

    order = @invoice1.payos_order || @invoice1.build_payos_order
    order.assign_attributes(
      order_code: 123456,
      checkout_url: "https://pay.payos.vn/web/test-embed-checkout",
      status: "PENDING",
      metadata: { "accountNumber" => "CAS00123", "description" => "HD123" }
    )
    order.save!

    get landlord_house_invoice_path(@house, @invoice1)
    assert_response :success
    assert_includes response.body, "https://pay.payos.vn/web/test-embed-checkout"
    assert_includes response.body, CGI.escapeHTML(I18n.t("invoice.payos.open_checkout"))
    assert_includes response.body, I18n.t("invoice.payos.static_qr_badge")
    assert_includes response.body, "CAS00123"
  end

  test "invoice show does not render payos checkout button when invoice is paid" do
    sign_in_as(@landlord_user)
    bank = Bank.find_or_create_by!(code: "MB") do |b|
      b.name = "Military Bank"
      b.short_name = "MB"
      b.bin = "970422"
    end
    bank_account = @landlord.bank_accounts.create!(
      bank: bank,
      account_number: "987654321",
      account_holder: "LANDLORD USER",
      payos_enabled: true,
      payos_client_id: "test-client-id",
      payos_api_key: "test-api-key",
      payos_checksum_key: "test-checksum-key"
    )
    @invoice1.update!(bank_account: bank_account, status: :paid, paid_at: Time.current)

    get landlord_house_invoice_path(@house, @invoice1)
    assert_response :success
    refute_includes response.body, CGI.escapeHTML(I18n.t("invoice.payos.open_checkout"))
    refute_includes response.body, I18n.t("invoice.payos.static_qr_notice_html")
  end
end
