# frozen_string_literal: true

require "test_helper"

class TenantServicesFilterTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Test",
      tel: "0901234501",
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
      fullname: "Tenant Test",
      tel: "0907654301",
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
      name: "Sunrise Apartments",
      mode: :room,
      address_l1: "123 Sunrise Blvd",
      address_l2: "Ward 5",
      address_l3: "District 2",
      floors_count: 2,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 2)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 28.0)
    @other_room = @floor.rooms.create!(name: "Room 102", max_slots: 2, tenants_count: 1, area: 28.0)

    @rental_unit = @room.create_rental_unit!(rent: 4_000_000, deposit: 4_000_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )

    # Services
    @service_elec = @house.services.create!(name: "Điện sinh hoạt")
    @variant_elec = @service_elec.service_variants.create!(
      fee: 3500,
      unit: "per_kwh",
      is_real_time: true
    )
    @room_service_elec = @room.room_services.create!(service_variant: @variant_elec)

    @service_water = @house.services.create!(name: "Nước máy")
    @variant_water = @service_water.service_variants.create!(
      fee: 25000,
      unit: "per_m3",
      is_real_time: true
    )
    @room_service_water = @room.room_services.create!(service_variant: @variant_water)

    @service_wifi = @house.services.create!(name: "Internet Cáp quang")
    @variant_wifi = @service_wifi.service_variants.create!(
      fee: 100000,
      unit: "per_room",
      is_real_time: false
    )
    @room_service_wifi = @room.room_services.create!(service_variant: @variant_wifi)

    @service_parking = @house.services.create!(name: "Gửi xe máy")
    @variant_parking = @service_parking.service_variants.create!(
      fee: 120000,
      unit: "per_month",
      is_real_time: false
    )
    # Applied only to other_room, NOT @room
    @other_room.room_services.create!(service_variant: @variant_parking)
  end

  test "returns all applied services for room sorted by service name when no query" do
    results = TenantServicesFilter.call(room: @room, params: {})

    assert_equal 3, results.total_count
    names = results.map { |rs| rs.service_variant.service.name }
    assert_equal [ "Điện sinh hoạt", "Internet Cáp quang", "Nước máy" ].sort, names.sort
    assert_not_includes names, "Gửi xe máy"
  end

  test "filters room services by search query case-insensitively" do
    results = TenantServicesFilter.call(room: @room, params: { query: "điện" })

    assert_equal 1, results.total_count
    assert_equal "Điện sinh hoạt", results.first.service_variant.service.name

    wifi_results = TenantServicesFilter.call(room: @room, params: { query: "internet" })
    assert_equal 1, wifi_results.total_count
    assert_equal "Internet Cáp quang", wifi_results.first.service_variant.service.name
  end

  test "returns empty results when query does not match any room services" do
    results = TenantServicesFilter.call(room: @room, params: { query: "Dịch vụ không tồn tại" })

    assert_equal 0, results.total_count
    assert_empty results
  end

  test "paginates results according to per_page and page params" do
    results_page1 = TenantServicesFilter.call(room: @room, params: { per_page: 2, page: 1 })
    assert_equal 2, results_page1.size
    assert_equal 2, results_page1.total_pages

    results_page2 = TenantServicesFilter.call(room: @room, params: { per_page: 2, page: 2 })
    assert_equal 1, results_page2.size
  end

  test "returns empty scope when room is nil" do
    results = TenantServicesFilter.call(room: nil, params: {})
    assert_empty results
  end
end
