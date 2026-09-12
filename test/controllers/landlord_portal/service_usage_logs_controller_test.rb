# frozen_string_literal: true

require "test_helper"

class LandlordPortal::ServiceUsageLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)
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
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25)
    @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @service = @house.services.create!(name: "Điện", note: "Điện sinh hoạt")
    @variant = @service.service_variants.create!(
      unit: "per_kwh",
      fee: 3500,
      is_real_time: true
    )
    @room_service = RoomService.create!(room: @room, service_variant: @variant, service: @service)

    @billing_month = Date.current.beginning_of_month
    @log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: @service.name,
      unit: @variant.human_unit,
      unit_price: @variant.fee,
      prev_reading: 100,
      latest_reading: 220,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: false,
      submitted_by: @landlord_user
    )

    sign_in_as(@landlord_user)
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

  test "should get house service usage logs index" do
    get landlord_house_service_usage_logs_path(@house)
    assert_response :success
    assert_select "h1", text: /#{I18n.t('invoice.meter_logs_title')}/
  end

  test "should get house service usage logs index scoped to service" do
    get landlord_house_service_usage_logs_path(@house, service_id: @service.id)
    assert_response :success
    assert_select "nav[aria-label*='readcrumb']", text: /#{@service.name}/
    assert_select "h1", text: /#{@service.name}/
    assert_select "select[name='floor_id']"
    assert_select "select[name='room_id']"
  end

  test "should get filtered logs for house with floor_id" do
    get filtered_landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"), floor_id: @floor.id)
    assert_response :success
    assert_select "turbo-frame#logs_table"
  end

  test "index renders floor name in room column" do
    get landlord_house_service_usage_logs_path(@house)
    assert_response :success
    assert_select "tr##{dom_id(@log)} td" do
      assert_select "span", text: /#{@floor.title_name}/
    end
  end

  test "index renders service name and price per unit in service column" do
    get landlord_house_service_usage_logs_path(@house)
    assert_response :success
    assert_select "tr##{dom_id(@log)} td" do
      assert_select "div", text: @log.service_name
      assert_select "span.badge", text: /#{ActiveSupport::NumberHelper.number_to_delimited(@log.unit_price)} đ \/ #{@log.unit}/
    end
  end

  test "room index renders service name and price per unit in service column" do
    get landlord_house_room_service_usage_logs_path(@house, @room)
    assert_response :success
    assert_select "tr##{dom_id(@log)} td" do
      assert_select "div", text: @log.service_name
      assert_select "span.badge", text: /#{ActiveSupport::NumberHelper.number_to_delimited(@log.unit_price)} đ \/ #{@log.unit}/
    end
  end

  test "show renders turbo modal with usage log details and timestamps" do
    @log.update!(
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by: @landlord_user
    )
    get landlord_house_service_usage_log_path(@house, @log), headers: { "Turbo-Frame" => "usage_log_detail_modal" }
    assert_response :success
    assert_select "turbo-frame#usage_log_detail_modal"
    assert_select "#usageLogDetailModal"
    assert_select ".modal-title", text: /#{@service.name}/
    assert_select ".badge", text: /#{@floor.title_name}/
  end

  test "should get dedicated room service usage logs index" do
    get landlord_house_room_service_usage_logs_path(@house, @room)
    assert_response :success
    assert_select "h1", text: /#{@room.name}/
    assert_select "a", text: /#{I18n.t("service_usage_logs.back_to_rooms")}/
  end

  test "should get filtered logs for house" do
    get filtered_landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
    assert_response :success
    assert_select "turbo-frame#logs_table"
  end

  test "should get filtered logs for room" do
    get filtered_landlord_house_service_usage_logs_path(@house, room_id: @room.id)
    assert_response :success
    assert_select "turbo-frame#room_logs_table"
  end

  test "should get new log form" do
    get new_landlord_house_service_usage_log_path(@house, room_id: @room.id)
    assert_response :success
  end

  test "should create service usage log" do
    assert_difference("ServiceUsageLog.count", 1) do
      post landlord_house_service_usage_logs_path(@house), params: {
        service_usage_log: {
          room_id: @room.id,
          service_id: @service.id,
          service_variant_id: @variant.id,
          service_name: @service.name,
          unit: @variant.human_unit,
          unit_price: @variant.fee,
          billing_month: @billing_month.next_month.strftime("%Y-%m"),
          start_date: @billing_month.next_month.beginning_of_month,
          end_date: @billing_month.next_month.end_of_month,
          prev_reading: 220,
          latest_reading: 350,
          is_confirmed: true
        }
      }
    end
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.next_month.strftime("%Y-%m"))
  end

  test "should confirm single log and lock tenant modifications" do
    assert_equal false, @log.is_confirmed?
    assert_equal true, @log.can_be_edited_by_tenant?

    patch confirm_landlord_house_service_usage_log_path(@house, @log)
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))

    @log.reload
    assert_equal true, @log.is_confirmed?
    assert_equal false, @log.can_be_edited_by_tenant?
  end

  test "should confirm all logs for room" do
    assert_equal false, @log.is_confirmed?

    patch confirm_all_landlord_house_room_service_usage_logs_path(@house, @room)
    assert_redirected_to landlord_house_room_service_usage_logs_path(@house, @room)

    @log.reload
    assert_equal true, @log.is_confirmed?
  end

  test "should confirm all logs for house" do
    assert_equal false, @log.is_confirmed?

    patch confirm_all_landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))

    @log.reload
    assert_equal true, @log.is_confirmed?
  end

  test "should allow landlord to update reading of unbilled log" do
    patch landlord_house_service_usage_log_path(@house, @log), params: {
      service_usage_log: {
        latest_reading: 235
      }
    }
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))

    @log.reload
    assert_equal 235, @log.latest_reading
    assert_equal 135, @log.usage_quantity
  end

  test "should destroy unbilled log" do
    assert_difference("ServiceUsageLog.count", -1) do
      delete landlord_house_service_usage_log_path(@house, @log)
    end
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
  end

  test "should not destroy billed log and show error alert" do
    invoice = Invoice.create!(
      code: "INV-TEST-BILLED",
      title: "HĐ test",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: @billing_month,
      due_date: @billing_month + 10.days,
      subtotal: 100_000,
      total_amount: 100_000,
      status: :pending
    )
    @log.update!(invoice: invoice)

    assert_no_difference("ServiceUsageLog.count") do
      delete landlord_house_service_usage_log_path(@house, @log)
    end
    assert_redirected_to landlord_house_service_usage_logs_path(@house)
    assert_equal I18n.t("service_usage_logs.cannot_delete_billed", default: "Chỉ số này đã được xuất hóa đơn, không thể xóa!"), flash[:alert]
  end

  test "should get room index with real_time tab by default when real_time service exists" do
    get landlord_house_room_service_usage_logs_path(@house, @room)
    assert_response :success
    assert_select "turbo-frame#room_service_logs_section"
    # Tab navigation present
    assert_select "a", text: /#{I18n.t('service_usage_logs.tab_real_time')}/
    assert_select "a", text: /#{I18n.t('service_usage_logs.tab_fixed')}/
    # Action buttons moved into real-time tab content
    assert_select "a", text: /#{I18n.t('service_usage_logs.record_reading')}/
    # Table of logs present
    assert_select "turbo-frame#room_logs_table"
  end

  test "should get room index with fixed tab and show fixed services" do
    fixed_service = @house.services.create!(name: "Internet", note: "Wifi tốc độ cao")
    fixed_variant = fixed_service.service_variants.create!(
      unit: "per_room",
      fee: 100_000,
      is_real_time: false
    )
    RoomService.create!(room: @room, service_variant: fixed_variant, service: fixed_service)

    get landlord_house_room_service_usage_logs_path(@house, @room, tab: "fixed")
    assert_response :success
    assert_select "turbo-frame#room_service_logs_section"
    # Shows fixed service details
    assert_select "div", text: /Internet/
    assert_select "div", text: /100,000 đ/
  end

  test "should automatically default to fixed tab when room has only fixed services" do
    fixed_room = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 1, area: 20)
    fixed_service = @house.services.create!(name: "Rác", note: "Vệ sinh môi trường")
    fixed_variant = fixed_service.service_variants.create!(
      unit: "per_room",
      fee: 50_000,
      is_real_time: false
    )
    RoomService.create!(room: fixed_room, service_variant: fixed_variant, service: fixed_service)

    get landlord_house_room_service_usage_logs_path(@house, fixed_room)
    assert_response :success
    # Should render fixed service content
    assert_select "div", text: /Rác/
    assert_select "div", text: /50,000 đ/
  end

  test "fixed tab shows actual billed quantity when active invoice exists and handles waived services" do
    past_month = 2.months.ago.beginning_of_month

    service_wifi = @house.services.create!(name: "Wifi")
    variant_wifi = service_wifi.service_variants.create!(unit: "per_room", fee: 100_000, is_real_time: false)
    rs_wifi = RoomService.create!(room: @room, service_variant: variant_wifi, service: service_wifi, created_at: 3.months.ago)

    service_trash = @house.services.create!(name: "Rác sinh hoạt")
    variant_trash = service_trash.service_variants.create!(unit: "per_room", fee: 30_000, is_real_time: false)
    rs_trash = RoomService.create!(room: @room, service_variant: variant_trash, service: service_trash, created_at: 3.months.ago)

    # Edge case: Washing machine was added yesterday (AFTER past_month)
    service_wash = @house.services.create!(name: "Máy giặt riêng")
    variant_wash = service_wash.service_variants.create!(unit: "per_room", fee: 150_000, is_real_time: false)
    rs_wash = RoomService.create!(room: @room, service_variant: variant_wash, service: service_wash, created_at: 1.day.ago)

    # Invoice for past_month ONLY billed Trash (Wifi was waived / not selected)
    invoice = Invoice.create!(
      code: "INV-PAST-01",
      title: "Hóa đơn tháng #{past_month.strftime('%m/%Y')}",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: past_month,
      due_date: past_month + 10.days,
      subtotal: 30_000,
      total_amount: 30_000,
      status: :paid,
      payment_method: :cash
    )
    invoice.invoice_items.create!(
      service_variant: variant_trash,
      item_type: "fixed_service",
      name: "Rác sinh hoạt",
      unit: "phòng",
      unit_price: 30_000,
      quantity: 1.0,
      amount: 30_000
    )

    get landlord_house_room_service_usage_logs_path(@house, @room, tab: "fixed", month: past_month.strftime("%Y-%m"))
    assert_response :success

    # Trash is billed
    assert_select "div", text: /Rác sinh hoạt/
    assert_select "span", text: /#{I18n.t('service_usage_logs.billed_in_invoice_badge')}/

    # Wifi was assigned at that time but waived from invoice -> displays with quantity 0
    assert_select "div", text: /Wifi/
    assert_select "span", text: /#{I18n.t('service_usage_logs.not_billed_in_invoice_badge')}/

    # Washing machine was added AFTER past_month -> MUST NOT APPEAR AT ALL!
    assert_select "div", text: /Máy giặt riêng/, count: 0
  end

  test "fixed tab shows warning banner and falls back to draft when invoice is cancelled" do
    past_month = 1.month.ago.beginning_of_month

    service_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    variant_wifi = service_wifi.service_variants.create!(unit: "per_room", fee: 80_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: variant_wifi, service: service_wifi, created_at: 2.months.ago)

    # Create a cancelled invoice
    cancelled_inv = Invoice.create!(
      code: "INV-CANCELLED-99",
      title: "Hóa đơn đã hủy",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: past_month,
      due_date: past_month + 10.days,
      subtotal: 80_000,
      total_amount: 80_000,
      status: :cancelled,
      discarded_at: Time.current
    )

    get landlord_house_room_service_usage_logs_path(@house, @room, tab: "fixed", month: past_month.strftime("%Y-%m"))
    assert_response :success

    # Shows cancelled invoice notice with code
    assert_select ".alert-warning", text: /INV-CANCELLED-99/
    # Falls back to estimated badge
    assert_select "span", text: /#{I18n.t('service_usage_logs.estimated_badge')}/
  end

  test "fixed tab shows warning banner for multiple cancelled invoices and links to filtered list" do
    past_month = 1.month.ago.beginning_of_month

    service_wifi = @house.services.create!(name: "Wifi Cáp Quang")
    variant_wifi = service_wifi.service_variants.create!(unit: "per_room", fee: 80_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: variant_wifi, service: service_wifi, created_at: 2.months.ago)

    # Create 2 cancelled invoices
    Invoice.create!(
      code: "INV-CANCEL-A1",
      title: "Hóa đơn đã hủy 1",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: past_month,
      due_date: past_month + 10.days,
      subtotal: 80_000,
      total_amount: 80_000,
      status: :cancelled,
      discarded_at: Time.current
    )
    Invoice.create!(
      code: "INV-CANCEL-B2",
      title: "Hóa đơn đã hủy 2",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: past_month,
      due_date: past_month + 10.days,
      subtotal: 80_000,
      total_amount: 80_000,
      status: :cancelled,
      discarded_at: Time.current
    )

    get landlord_house_room_service_usage_logs_path(@house, @room, tab: "fixed", month: past_month.strftime("%Y-%m"))
    assert_response :success

    # Shows both codes in warning notice
    assert_select ".alert-warning", text: /INV-CANCEL-A1/
    assert_select ".alert-warning", text: /INV-CANCEL-B2/
    # Link to filtered cancelled invoices list
    assert_select ".alert-warning a", text: /#{I18n.t('service_usage_logs.view_cancelled_invoices_list')}/
    # Count badge in stat card
    assert_select ".stat-card", text: /#{I18n.t('service_usage_logs.cancelled_invoices_count_badge', count: 2)}/
  end

  test "fixed tab supports pagination when fixed services exceed per_page" do
    12.times do |i|
      svc = @house.services.create!(name: "Fixed Svc #{i + 1}")
      variant = svc.service_variants.create!(unit: "per_room", fee: 10_000, is_real_time: false)
      RoomService.create!(room: @room, service_variant: variant, service: svc)
    end

    get landlord_house_room_service_usage_logs_path(@house, @room, tab: "fixed", page: 1)
    assert_response :success
    assert_select "span[data-pagination-total-pages]", minimum: 1
    assert_select ".pagination", minimum: 1

    get landlord_house_room_service_usage_logs_path(@house, @room, tab: "fixed", page: 2)
    assert_response :success
  end

  test "new log form renders confirmation mode radio buttons" do
    get new_landlord_house_service_usage_log_path(@house, room_id: @room.id)
    assert_response :success
    assert_select "input[type=radio][name='service_usage_log[is_confirmed]'][value='true']"
    assert_select "input[type=radio][name='service_usage_log[is_confirmed]'][value='false']"
  end

  test "new log form renders floor and dependent room fields as an input group" do
    get new_landlord_house_service_usage_log_path(@house, room_id: @room.id)
    assert_response :success

    assert_select "div[data-controller='dependent-rental-unit']" do
      assert_select ".input-group" do
        assert_select "label[for='floor_id']", text: /#{I18n.t('form.floor.self')}/
        assert_select "select#floor_id[data-dependent-rental-unit-target='floor']"
        assert_select "label[for='service_usage_log_room_id']", text: /#{I18n.t('form.room.self')}/
        assert_select "select#service_usage_log_room_id[data-dependent-rental-unit-target='room']"
      end
    end
  end

  test "creates unconfirmed service usage log when is_confirmed is false even without latest_reading" do
    next_month = 2.months.from_now.beginning_of_month
    assert_difference("ServiceUsageLog.count", 1) do
      post landlord_house_service_usage_logs_path(@house), params: {
        service_usage_log: {
          billing_month: next_month.strftime("%Y-%m"),
          room_id: @room.id,
          service_id: @service.id,
          service_variant_id: @variant.id,
          service_name: @service.name,
          unit: @variant.human_unit,
          unit_price: @variant.fee,
          prev_reading: 220,
          latest_reading: nil,
          is_confirmed: false,
          start_date: next_month,
          end_date: next_month.end_of_month
        }
      }
    end
    assert_response :redirect
    created_log = ServiceUsageLog.last
    assert_not created_log.is_confirmed?
    assert_nil created_log.latest_reading
  end

  test "cannot create confirmed service usage log when latest_reading is blank" do
    next_month = 3.months.from_now.beginning_of_month
    assert_no_difference("ServiceUsageLog.count") do
      post landlord_house_service_usage_logs_path(@house), params: {
        service_usage_log: {
          billing_month: next_month.strftime("%Y-%m"),
          room_id: @room.id,
          service_id: @service.id,
          service_variant_id: @variant.id,
          service_name: @service.name,
          unit: @variant.human_unit,
          unit_price: @variant.fee,
          prev_reading: 220,
          latest_reading: nil,
          is_confirmed: true,
          start_date: next_month,
          end_date: next_month.end_of_month
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "confirming log sends notification to active staying tenants in room" do
    tenant_user = User.create!(
      fullname: "Staying Tenant",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "Room 101",
      tel_verified_at: Time.current
    )
    tenant = Tenant.find_or_create_by!(id: tenant_user.id)
    TenantStay.create!(
      rental_unit: @room.rental_unit,
      tenant: tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )

    assert_difference -> { Noticed::Notification.where(recipient: tenant_user).count }, 1 do
      patch confirm_landlord_house_service_usage_log_path(@house, @log)
    end
    assert_response :redirect
    assert @log.reload.is_confirmed?
  end

  test "whole house index with tab fixed renders fixed services summary" do
    fixed_svc = @house.services.create!(name: "Wifi Cáp Quang")
    fixed_var = fixed_svc.service_variants.create!(unit: "per_room", fee: 100_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: fixed_var, service: fixed_svc)

    get landlord_house_service_usage_logs_path(@house, tab: "fixed", month: @billing_month.strftime("%Y-%m"))
    assert_response :success
    assert_select "turbo-frame#house_service_logs_section" do
      assert_select "turbo-frame#house_fixed_services_table"
      assert_select "td", text: /Wifi Cáp Quang/
    end
  end

  test "whole house index auto-selects fixed tab when fixed service is passed" do
    fixed_svc = @house.services.create!(name: "Rác Sinh Hoạt")
    fixed_var = fixed_svc.service_variants.create!(unit: "per_month", fee: 30_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: fixed_var, service: fixed_svc)

    get landlord_house_service_usage_logs_path(@house, service_id: fixed_svc.id, month: @billing_month.strftime("%Y-%m"))
    assert_response :success
    assert_select "turbo-frame#house_service_logs_section" do
      assert_select "turbo-frame#house_fixed_services_table"
      assert_select "td", text: /Rác Sinh Hoạt/
    end
  end

  test "whole house filtered action renders house_fixed_services_table partial when tab is fixed" do
    fixed_svc = @house.services.create!(name: "Gửi Xe")
    fixed_var = fixed_svc.service_variants.create!(unit: "per_item", fee: 50_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: fixed_var, service: fixed_svc)

    get filtered_landlord_house_service_usage_logs_path(@house, tab: "fixed", month: @billing_month.strftime("%Y-%m"))
    assert_response :success
    assert_select "turbo-frame#house_fixed_services_table"
    assert_select "td", text: /Gửi Xe/
  end
end
