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
    assert_select "a[href='#{tenant_service_usage_logs_path}']", text: /#{I18n.t("clear_filter", default: "Xóa bộ lọc")}/
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
end
