# frozen_string_literal: true

require "test_helper"

class TenantPortal::ServiceUsageLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Log Test",
      tel: "0901234503",
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
      fullname: "Tenant Log Test",
      tel: "0907654303",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 24.years.ago.to_date,
      address: "456 Tenant Ave",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Star Residence",
      mode: :room,
      address_l1: "789 Star Blvd",
      address_l2: "Ward 2",
      address_l3: "District 1",
      floors_count: 2,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 2)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 30.0)

    @rental_unit = @room.create_rental_unit!(rent: 4_500_000, deposit: 4_500_000)

    # Tenant checked in 1 month ago
    @checkin_date = 1.month.ago.beginning_of_month
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: @checkin_date,
      checkout_at: nil
    )

    @service_elec = @house.services.create!(name: "Điện")
    @variant_elec = @service_elec.service_variants.create!(fee: 4000, unit: "per_kwh", is_real_time: true)
    @room.room_services.create!(service_variant: @variant_elec)

    # Pre-stay log (from 3 months ago, should be HIDDEN from current tenant)
    @pre_stay_month = 3.months.ago.beginning_of_month
    @pre_stay_log = @room.service_usage_logs.create!(
      service: @service_elec,
      service_variant: @variant_elec,
      service_name: "Điện",
      unit: "kWh",
      unit_price: 4000,
      billing_month: @pre_stay_month,
      start_date: @pre_stay_month,
      end_date: @pre_stay_month.end_of_month,
      prev_reading: 100,
      latest_reading: 150,
      is_confirmed: true
    )

    # During-stay log (current month, should be VISIBLE to current tenant)
    @current_month = Date.current.beginning_of_month
    @during_stay_log = @room.service_usage_logs.create!(
      service: @service_elec,
      service_variant: @variant_elec,
      service_name: "Điện",
      unit: "kWh",
      unit_price: 4000,
      billing_month: @current_month,
      start_date: @current_month,
      end_date: @current_month.end_of_month,
      prev_reading: 200,
      latest_reading: nil,
      is_confirmed: false
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

  test "GET index requires authentication" do
    get tenant_service_usage_logs_path
    assert_redirected_to login_path
  end

  test "GET index highlights Services navigation link when visiting /tenant/service_usage_logs" do
    sign_in_as(@tenant_user)

    get tenant_service_usage_logs_path
    assert_response :success

    # Ensure Services nav link is marked active
    assert_select "li.nav-item.active a.nav-link.active[href='#{tenant_services_path}']"
  end

  test "GET index renders generalized title with room and floor names" do
    sign_in_as(@tenant_user)

    get tenant_service_usage_logs_path
    assert_response :success

    assert_includes response.body, I18n.t("invoice.service_usage_details")
    assert_includes response.body, @room.title_name
    assert_includes response.body, @floor.title_name
  end

  test "GET index scopes usage logs to stay commencement date and renders stay notice" do
    sign_in_as(@tenant_user)

    get tenant_service_usage_logs_path
    assert_response :success

    # Notice banner indicating stay commencement
    expected_stay_month = @checkin_date.strftime("%m/%Y")
    assert_includes response.body, I18n.t("invoice.tenant_history_scope_notice", month: expected_stay_month)

    # During-stay log is shown
    assert_includes response.body, @during_stay_log.billing_month.strftime("%m/%Y")

    # Pre-stay log is NOT shown
    assert_not_includes response.body, @pre_stay_log.billing_month.strftime("%m/%Y")
  end

  test "GET index month filter restricts min attribute to stay commencement month" do
    sign_in_as(@tenant_user)

    get tenant_service_usage_logs_path
    assert_response :success

    expected_min_month = @checkin_date.strftime("%Y-%m")
    assert_select "input[type='month'][name='month'][min='#{expected_min_month}']"
  end

  test "GET index filters by active month successfully" do
    sign_in_as(@tenant_user)

    get tenant_service_usage_logs_path(month: @current_month.strftime("%Y-%m"))
    assert_response :success

    assert_includes response.body, @during_stay_log.billing_month.strftime("%m/%Y")
    assert_select "input[type='month'][name='month'][value='#{@current_month.strftime("%Y-%m")}']"
  end

  test "GET index prevents access to pre-stay months and renders empty state" do
    sign_in_as(@tenant_user)

    # Attempt to query a month before stay commencement
    get tenant_service_usage_logs_path(month: @pre_stay_month.strftime("%Y-%m"))
    assert_response :success

    assert_not_includes response.body, @pre_stay_log.billing_month.strftime("%m/%Y")
    assert_includes response.body, I18n.t("invoice.no_logs_for_month")
  end

  test "GET edit on pre-stay log returns not found" do
    sign_in_as(@tenant_user)

    get edit_tenant_service_usage_log_path(@pre_stay_log)
    assert_response :not_found
  end

  test "GET index renders service name and price per unit badge in service column" do
    sign_in_as(@tenant_user)

    get tenant_service_usage_logs_path
    assert_response :success
    assert_select "tr td" do
      assert_select "div", text: @during_stay_log.service_name
      assert_select "span.badge", text: /#{ActiveSupport::NumberHelper.number_to_delimited(@during_stay_log.unit_price)} đ \/ #{@during_stay_log.unit}/
    end
  end

  test "GET index with tab=fixed renders fixed services view and NO stat cards" do
    svc_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    var_wifi = svc_wifi.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_wifi, service: svc_wifi)

    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path(tab: "fixed")
    assert_response :success

    # Check tab navigation
    assert_select ".log-tab.active", text: /#{I18n.t("service_usage_logs.tab_fixed")}/
    assert_select ".log-tab", text: /#{I18n.t("service_usage_logs.tab_real_time")}/

    # Critical requirement: Tenants do NOT need stat cards
    assert_select ".stat-card", 0

    # Filter and usage table
    assert_select "input[type='month'][name='month']"
    assert_select "table.table"
    assert_includes response.body, "Wifi Cáp Quang"
    assert_includes response.body, I18n.t("service_usage_logs.estimated_badge")
  end

  test "GET index with tab=fixed displays billed badge and invoice link when active invoice exists" do
    svc_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    var_wifi = svc_wifi.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_wifi, service: svc_wifi)

    invoice = Invoice.create!(
      code: "INV-TENANT-FIXED",
      title: "Hóa đơn tháng",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: @current_month,
      due_date: @current_month + 10.days,
      subtotal: 100_000,
      total_amount: 100_000,
      status: :pending
    )
    invoice.invoice_items.create!(
      service_variant: var_wifi,
      item_type: "fixed_service",
      name: "Wifi Cáp Quang",
      unit: "phòng",
      unit_price: 100_000,
      quantity: 1.0,
      amount: 100_000
    )

    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path(tab: "fixed")
    assert_includes response.body, I18n.t("service_usage_logs.billed_in_invoice_badge")
    assert_select "thead tr th", count: 5
    assert_select "td[colspan='5'] a[href='#{tenant_invoice_path(invoice)}'][target='_blank']", text: /#{invoice.code}/
  end

  test "GET index with tab=fixed maps multiple invoices to corresponding service rows in that month" do
    svc_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    var_wifi = svc_wifi.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_wifi, service: svc_wifi)

    svc_trash = @house.services.create!(name: "Thu gom rác")
    var_trash = svc_trash.service_variants.create!(fee: 30_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_trash, service: svc_trash)

    # Invoice 1 bills Wifi
    inv1 = Invoice.create!(
      code: "INV-MULTI-01",
      title: "Hóa đơn đợt 1",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: @current_month,
      due_date: @current_month + 10.days,
      subtotal: 100_000,
      total_amount: 100_000,
      status: :pending
    )
    inv1.invoice_items.create!(
      service_variant: var_wifi,
      item_type: "fixed_service",
      name: "Wifi Cáp Quang",
      unit: "phòng",
      unit_price: 100_000,
      quantity: 1.0,
      amount: 100_000
    )

    # Invoice 2 bills Trash
    inv2 = Invoice.create!(
      code: "INV-MULTI-02",
      title: "Hóa đơn đợt 2",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: @current_month,
      due_date: @current_month + 10.days,
      subtotal: 30_000,
      total_amount: 30_000,
      status: :pending
    )
    inv2.invoice_items.create!(
      service_variant: var_trash,
      item_type: "fixed_service",
      name: "Thu gom rác",
      unit: "phòng",
      unit_price: 30_000,
      quantity: 1.0,
      amount: 30_000
    )

    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path(tab: "fixed")
    assert_response :success

    # Table contains spanning header rows for BOTH invoices with target='_blank'
    assert_select "td[colspan='5'] a[href='#{tenant_invoice_path(inv1)}'][target='_blank']", text: /#{inv1.code}/
    assert_select "td[colspan='5'] a[href='#{tenant_invoice_path(inv2)}'][target='_blank']", text: /#{inv2.code}/

    # Both show as billed
    assert_select "span.badge", text: I18n.t("service_usage_logs.billed_in_invoice_badge"), count: 2
  end

  test "GET index with tab=fixed displays cancelled invoice notice when invoice was cancelled" do
    svc_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    var_wifi = svc_wifi.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_wifi, service: svc_wifi)

    cancelled_inv = Invoice.create!(
      code: "INV-CANCELLED",
      title: "Hóa đơn hủy",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: @current_month,
      due_date: @current_month + 10.days,
      subtotal: 100_000,
      total_amount: 100_000,
      status: :cancelled
    )

    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path(tab: "fixed")
    assert_response :success

    assert_includes response.body, I18n.t("service_usage_logs.cancelled_invoice_notice", code: cancelled_inv.code)
  end

  test "defaults to tab=fixed if room only has fixed services" do
    @room.room_services.destroy_all
    svc_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    var_wifi = svc_wifi.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_wifi, service: svc_wifi)

    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path
    assert_response :success

    assert_select ".log-tab.active", text: /#{I18n.t("service_usage_logs.tab_fixed")}/
  end

  test "GET index in realtime tab renders billing month explanation modal, trigger button, and tooltips" do
    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path(tab: "real_time")
    assert_response :success

    # Guide modal trigger button and modal dialog are rendered
    assert_select "button[data-bs-target='#billingMonthGuideModal']", text: /(?:#{I18n.t("service_usage_logs.billing_month_guide_btn")}|#{I18n.t("guide")})/
    assert_select "#billingMonthGuideModal"

    # Explanation content inside modal is rendered
    assert_includes response.body, I18n.t("service_usage_logs.billing_month_expl_title")
    assert_includes response.body, I18n.t("service_usage_logs.formula_label")
    assert_includes response.body, I18n.t("service_usage_logs.billing_rule_label")

    # Tooltip on table header and label
    assert_includes response.body, ERB::Util.html_escape(I18n.t("service_usage_logs.billing_month_explanation_tooltip"))
  end

  test "GET index in realtime tab defaults to current month and filters by month only without current month select button" do
    sign_in_as(@tenant_user)

    # Create a previous month log during stay
    last_month = 1.month.ago.beginning_of_month
    @room.service_usage_logs.create!(
      service: @service_elec,
      service_variant: @variant_elec,
      service_name: "Điện",
      unit: "kWh",
      unit_price: 4000,
      billing_month: last_month,
      start_date: last_month,
      end_date: last_month.end_of_month,
      prev_reading: 150,
      latest_reading: 200,
      is_confirmed: true
    )

    # 1. When unfiltered: defaults to current month, only shows current month log
    get tenant_service_usage_logs_path(tab: "real_time")
    assert_response :success

    # Month input value is current month
    assert_select "input[type='month'][name='month'][value='#{@current_month.strftime("%Y-%m")}']"

    # Shows current month log, does NOT show last month log
    assert_includes response.body, @during_stay_log.billing_month.strftime("%m/%Y")
    assert_not_includes response.body, "150" # last_month_log prev reading

    # Button to select current month and all months elements are NOT present
    assert_not_includes response.body, I18n.t("service_usage_logs.filter_current_month", month: Date.current.strftime("%m/%Y"))
    assert_not_includes response.body, I18n.t("service_usage_logs.default_all_months")
    assert_not_includes response.body, I18n.t("service_usage_logs.view_all_months")

    # 2. When filtered by specific month (e.g. last month): shows that month's log only
    get tenant_service_usage_logs_path(tab: "real_time", month: last_month.strftime("%Y-%m"))
    assert_response :success

    assert_select "input[type='month'][name='month'][value='#{last_month.strftime("%Y-%m")}']"
    assert_includes response.body, "150"
  end

  test "GET index in fixed tab defaults to current month, filters by month, and displays current month without reset button" do
    svc_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    var_wifi = svc_wifi.service_variants.create!(fee: 100_000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: var_wifi, service: svc_wifi)

    sign_in_as(@tenant_user)

    # 1. Unfiltered request in fixed tab defaults to current month
    get tenant_service_usage_logs_path(tab: "fixed")
    assert_response :success

    assert_select "input#fixed_month_filter[type='month'][name='month'][value='#{@current_month.strftime("%Y-%m")}']"
    assert_includes response.body, "Wifi Cáp Quang"
    assert_includes response.body, I18n.t("service_usage_logs.filtering_month", month: @current_month.strftime("%m/%Y"))

    # Reset button is not present
    assert_not_includes response.body, I18n.t("service_usage_logs.reset_to_current_month")

    # 2. Filtered by specific month (e.g. 1 month ago)
    last_month = 1.month.ago.beginning_of_month
    get tenant_service_usage_logs_path(tab: "fixed", month: last_month.strftime("%Y-%m"))
    assert_response :success

    assert_select "input#fixed_month_filter[type='month'][name='month'][value='#{last_month.strftime("%Y-%m")}']"
    assert_includes response.body, I18n.t("service_usage_logs.filtering_month", month: last_month.strftime("%m/%Y"))
    assert_not_includes response.body, I18n.t("service_usage_logs.reset_to_current_month")
  end

  test "GET index includes month parameter in tab links and default params for both tabs" do
    sign_in_as(@tenant_user)

    target_month = 1.month.ago.beginning_of_month
    month_str = target_month.strftime("%Y-%m")

    # In real_time tab
    get tenant_service_usage_logs_path(tab: "real_time", month: month_str)
    assert_response :success

    # Tab links preserve month
    assert_select "a[href*='tab=real_time'][href*='month=#{month_str}']"
    assert_select "a[href*='tab=fixed'][href*='month=#{month_str}']"

    # Frame default params value contains both tab and month
    assert_select "turbo-frame#tenant_service_logs_section" do |elements|
      default_params_json = elements.first["data-pagination-sync-default-params-value"]
      parsed_params = JSON.parse(default_params_json)
      assert_equal "real_time", parsed_params["tab"]
      assert_equal month_str, parsed_params["month"]
    end

    # In fixed tab
    get tenant_service_usage_logs_path(tab: "fixed", month: month_str)
    assert_response :success

    assert_select "a[href*='tab=real_time'][href*='month=#{month_str}']"
    assert_select "a[href*='tab=fixed'][href*='month=#{month_str}']"

    assert_select "turbo-frame#tenant_service_logs_section" do |elements|
      default_params_json = elements.first["data-pagination-sync-default-params-value"]
      parsed_params = JSON.parse(default_params_json)
      assert_equal "fixed", parsed_params["tab"]
      assert_equal month_str, parsed_params["month"]
    end
  end

  test "GET index accepts single digit month format like 2026-1 and parses to 2026-01 without falling back to current month" do
    sign_in_as(@tenant_user)

    # 1. Real time tab with single digit month 2026-1
    get tenant_service_usage_logs_path(tab: "real_time", month: "2026-1")
    assert_response :success

    # Input value should be 2026-01
    assert_select "input#realtime_month_filter[type='month'][value='2026-01']"

    # Tab links should have month=2026-01
    assert_select "a[href*='month=2026-01']"

    # Default params should have month: 2026-01
    assert_select "turbo-frame#tenant_service_logs_section" do |elements|
      parsed_params = JSON.parse(elements.first["data-pagination-sync-default-params-value"])
      assert_equal "2026-01", parsed_params["month"]
    end

    # 2. Fixed tab with single digit month 2026-1
    get tenant_service_usage_logs_path(tab: "fixed", month: "2026-1")
    assert_response :success

    assert_select "input#fixed_month_filter[type='month'][value='2026-01']"
    assert_select "a[href*='month=2026-01']"
  end

  test "both complete and incomplete logs created by landlord are displayed in tenant index" do
    sign_in_as(@tenant_user)

    # Incomplete log created by landlord (@during_stay_log has is_confirmed: false, latest_reading: nil)
    # Create another complete log for the same month
    other_service = @house.services.create!(name: "Nước")
    variant_water = other_service.service_variants.create!(fee: 20_000, unit: "per_m3", is_real_time: true)
    @room.room_services.create!(service_variant: variant_water)
    complete_log = @room.service_usage_logs.create!(
      service: other_service,
      service_variant: variant_water,
      service_name: "Nước",
      unit: "m³",
      unit_price: 20_000,
      billing_month: @current_month,
      start_date: @current_month,
      end_date: @current_month.end_of_month,
      prev_reading: 50,
      latest_reading: 65,
      is_confirmed: true
    )

    get tenant_service_usage_logs_path(month: @current_month.strftime("%Y-%m"))
    assert_response :success

    # Complete log shows locked status
    assert_select "tr", text: /Nước/ do
      assert_select "span", text: /#{I18n.t('invoice.confirmed_and_locked')}/
      assert_select "span", text: /#{I18n.t('invoice.locked')}/
    end

    # Incomplete log shows editable status and submit action button
    assert_select "tr", text: /Điện/ do
      assert_select "span", text: /#{I18n.t('invoice.editable')}/
      assert_select "a[href='#{edit_tenant_service_usage_log_path(@during_stay_log)}']", text: /#{I18n.t('invoice.submit_reading_or_photo')}/
    end

    # There should NOT be any button for tenant to create a new log from scratch
    assert_select "a", text: /#{I18n.t('invoice.submit_new_meter_reading')}/, count: 0
  end

  test "tenant can upload photo and submit reading to an incomplete log" do
    sign_in_as(@tenant_user)
    file = fixture_file_upload("normal.png", "image/png")

    get edit_tenant_service_usage_log_path(@during_stay_log)
    assert_response :success
    assert_select "input[name='service_usage_log[latest_reading]']"
    assert_select "input[type=file][name='service_usage_log[reading_photo]']"

    patch tenant_service_usage_log_path(@during_stay_log), params: {
      service_usage_log: {
        latest_reading: 350,
        reading_photo: file
      }
    }

    assert_redirected_to tenant_service_usage_logs_path(month: @during_stay_log.billing_month.strftime("%Y-%m"))
    @during_stay_log.reload
    assert_equal 350, @during_stay_log.latest_reading
    assert_not @during_stay_log.is_confirmed?
    assert_equal @tenant_user, @during_stay_log.submitted_by
    assert @during_stay_log.reading_photo.attached?
  end

  test "tenant updating incomplete log without photo fails if none attached" do
    sign_in_as(@tenant_user)

    patch tenant_service_usage_log_path(@during_stay_log), params: {
      service_usage_log: {
        latest_reading: 350,
        reading_photo: nil
      }
    }

    assert_response :unprocessable_entity
    assert_nil @during_stay_log.reload.latest_reading
  end

  test "tenant cannot edit or update confirmed service usage log" do
    sign_in_as(@tenant_user)
    @during_stay_log.update!(latest_reading: 280, is_confirmed: true)

    get edit_tenant_service_usage_log_path(@during_stay_log)
    assert_redirected_to tenant_service_usage_logs_path
    assert_equal I18n.t("errors.landlord_confirm"), flash[:alert]

    patch tenant_service_usage_log_path(@during_stay_log), params: {
      service_usage_log: { latest_reading: 300 }
    }
    assert_redirected_to tenant_service_usage_logs_path
    assert_equal 280, @during_stay_log.reload.latest_reading
  end

  test "modal guide explains tenant photo submission instructions" do
    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path
    assert_response :success
    assert_select "#billingMonthGuideModal", text: /#{I18n.t('service_usage_logs.tenant_guide_step_title')}/
  end

  test "GET index renders each row within a unique turbo frame" do
    sign_in_as(@tenant_user)
    get tenant_service_usage_logs_path
    assert_response :success

    frame_id = ActionView::RecordIdentifier.dom_id(@during_stay_log)
    assert_select "turbo-frame##{frame_id}.table-row-frame"
  end

  test "GET edit renders edit form" do
    sign_in_as(@tenant_user)

    get edit_tenant_service_usage_log_path(@during_stay_log)
    assert_response :success

    assert_select "form" do
      assert_select "input[name='service_usage_log[latest_reading]']"
      assert_select "input[type=file][name='service_usage_log[reading_photo]']"
      assert_select "[data-controller~='file-preview']" do
        assert_select "input[type=file][data-file-preview-target='input'][data-action*='file-preview#preview']"
        assert_select "[data-file-preview-target='container']" do
          assert_select "img[data-file-preview-target='preview']"
          assert_select "button[data-action*='file-preview#clear']"
        end
      end
    end
    assert_select "a[href='#{tenant_service_usage_log_path(@during_stay_log)}']", text: /#{I18n.t('invoice.actions.back')}/
  end

  test "GET show with Turbo-Frame header restores normal row partial" do
    sign_in_as(@tenant_user)
    frame_id = ActionView::RecordIdentifier.dom_id(@during_stay_log)

    get tenant_service_usage_log_path(@during_stay_log), headers: { "Turbo-Frame" => frame_id }
    assert_response :success

    assert_select "turbo-frame##{frame_id}.table-row-frame" do
      assert_select "a[href='#{edit_tenant_service_usage_log_path(@during_stay_log)}']"
    end
    assert_includes response.body, @during_stay_log.service_name
  end

  test "PATCH update with turbo_stream replaces row frame and updates flash" do
    sign_in_as(@tenant_user)
    file = fixture_file_upload("normal.png", "image/png")
    frame_id = ActionView::RecordIdentifier.dom_id(@during_stay_log)

    patch tenant_service_usage_log_path(@during_stay_log),
          params: {
            service_usage_log: {
              latest_reading: 380,
              reading_photo: file
            }
          },
          as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type

    # Replaces the row frame
    assert_select "turbo-stream[action='replace'][target='#{frame_id}']" do
      assert_select "turbo-frame##{frame_id}.table-row-frame"
      assert_includes response.body, "380"
    end

    # Updates flash message
    assert_select "turbo-stream[action='update'][target='flash']"

    @during_stay_log.reload
    assert_equal 380, @during_stay_log.latest_reading
  end

  test "PATCH update with validation error re-renders edit form with 422" do
    sign_in_as(@tenant_user)

    patch tenant_service_usage_log_path(@during_stay_log),
          params: {
            service_usage_log: {
              latest_reading: 380,
              reading_photo: nil
            }
          }

    assert_response :unprocessable_entity
    assert_select "form"
    assert_includes response.body, I18n.t("invoice.reading_photo_required")
  end

  test "GET edit on log with attached photo renders preview container visible with existing photo" do
    sign_in_as(@tenant_user)
    @during_stay_log.reading_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "normal.png",
      content_type: "image/png"
    )

    get edit_tenant_service_usage_log_path(@during_stay_log)
    assert_response :success
    assert_select "[data-file-preview-target='container']" do |containers|
      assert_not_includes containers.first["class"], "d-none"
    end
    assert_select "img[data-file-preview-target='preview']"
    assert_select "button[data-action*='file-preview#clear']"
  end

  test "PATCH update with purge_reading_photo=1 purges photo and requires photo if none provided" do
    sign_in_as(@tenant_user)
    @during_stay_log.reading_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "normal.png",
      content_type: "image/png"
    )
    assert @during_stay_log.reading_photo.attached?

    patch tenant_service_usage_log_path(@during_stay_log),
          params: {
            service_usage_log: {
              latest_reading: 380,
              purge_reading_photo: "1"
            }
          },
          as: :turbo_stream

    assert_response :unprocessable_entity
    assert_not @during_stay_log.reload.reading_photo.attached?
    assert_includes response.body, I18n.t("invoice.reading_photo_required")
  end

  test "PATCH update from form with Turbo-Frame _top redirects to tenant_service_usage_logs_path" do
    sign_in_as(@tenant_user)
    file = fixture_file_upload("normal.png", "image/png")

    patch tenant_service_usage_log_path(@during_stay_log),
          params: {
            service_usage_log: {
              latest_reading: 380,
              reading_photo: file
            }
          },
          headers: { "Turbo-Frame" => "_top" },
          as: :turbo_stream

    assert_redirected_to tenant_service_usage_logs_path(month: @during_stay_log.billing_month.strftime("%Y-%m"))
  end
end
