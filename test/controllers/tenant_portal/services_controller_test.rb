# frozen_string_literal: true

require "test_helper"

class TenantPortal::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Services Test",
      tel: "0901234502",
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
      fullname: "Tenant Services Test",
      tel: "0907654302",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 25.years.ago.to_date,
      address: "456 Tenant Ave",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Green Garden Apartments",
      mode: :room,
      address_l1: "456 Green St",
      address_l2: "Ward 1",
      address_l3: "District 3",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 2)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @other_room = @floor.rooms.create!(name: "Room 102", max_slots: 2, tenants_count: 1, area: 25.0)

    @rental_unit = @room.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )

    # Applied services for @room
    @service_elec = @house.services.create!(name: "Điện sinh hoạt")
    @variant_elec = @service_elec.service_variants.create!(fee: 3800, unit: "per_kwh", is_real_time: true)
    @room.room_services.create!(service_variant: @variant_elec)

    @service_water = @house.services.create!(name: "Nước sinh hoạt")
    @variant_water = @service_water.service_variants.create!(fee: 30000, unit: "per_m3", is_real_time: true)
    @room.room_services.create!(service_variant: @variant_water)

    @service_wifi = @house.services.create!(name: "Cáp quang FPT")
    @variant_wifi = @service_wifi.service_variants.create!(fee: 80000, unit: "per_room", is_real_time: false)
    @room.room_services.create!(service_variant: @variant_wifi)

    # Service applied only to other room
    @service_cleaning = @house.services.create!(name: "Vệ sinh hành lang")
    @variant_cleaning = @service_cleaning.service_variants.create!(fee: 50000, unit: "per_month", is_real_time: false)
    @other_room.room_services.create!(service_variant: @variant_cleaning)
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
    get tenant_services_path
    assert_redirected_to login_path
  end

  test "GET index renders applied services with search toolbar and turbo frame" do
    sign_in_as(@tenant_user)

    get tenant_services_path
    assert_response :success

    # Check search toolbar
    assert_select "form[data-controller='search'][data-turbo-frame='tenant_services_table']"
    assert_select "input[type='search'][name='query']"

    # Check turbo frame and sync
    assert_select "turbo-frame#tenant_services_table[data-controller='pagination-sync']"

    # Check services in table
    assert_includes response.body, "Điện sinh hoạt"
    assert_includes response.body, "Nước sinh hoạt"
    assert_includes response.body, "Cáp quang FPT"
    assert_not_includes response.body, "Vệ sinh hành lang"
  end

  test "GET index filters services by query" do
    sign_in_as(@tenant_user)

    # Search matching "Điện"
    get tenant_services_path(query: "Điện")
    assert_response :success

    assert_includes response.body, "Điện sinh hoạt"
    assert_not_includes response.body, "Nước sinh hoạt"
    assert_not_includes response.body, "Cáp quang FPT"

    # Clear filter button is visible (no d-none) when query is given
    assert_select "button[data-search-target='clearButton']:not(.d-none)"
  end

  test "GET index renders search-empty state when query has no matches" do
    sign_in_as(@tenant_user)

    get tenant_services_path(query: "Dịch vụ không có")
    assert_response :success

    assert_select ".service-empty-state"
    assert_includes response.body, I18n.t("service.no_matching_services", default: I18n.t("service.filter_empty"))
  end

  test "GET index pagination splits results when items exceed per_page" do
    sign_in_as(@tenant_user)

    get tenant_services_path(per_page: 2, page: 1)
    assert_response :success

    assert_select "[data-pagination-total-pages='2']"
    assert_select ".pagination"
  end
end
