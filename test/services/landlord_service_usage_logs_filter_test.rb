# frozen_string_literal: true

require "test_helper"

class LandlordServiceUsageLogsFilterTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Filter Test Landlord",
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
      name: "Filter House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room1 = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25)
    @room1.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @room2 = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 1, area: 25)
    @room2.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @service1 = @house.services.create!(name: "Điện", note: "Điện sinh hoạt")
    @variant1 = @service1.service_variants.create!(unit: "per_kwh", fee: 3500, is_real_time: true)

    @service2 = @house.services.create!(name: "Nước", note: "Nước sinh hoạt")
    @variant2 = @service2.service_variants.create!(unit: "per_m3", fee: 20000, is_real_time: true)

    @billing_month = Date.current.beginning_of_month
    @prev_month = 1.month.ago.beginning_of_month

    @log1 = ServiceUsageLog.create!(
      room: @room1,
      service: @service1,
      service_variant: @variant1,
      service_name: @service1.name,
      unit: @variant1.human_unit,
      unit_price: @variant1.fee,
      prev_reading: 100,
      latest_reading: 200,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: false,
      submitted_by: @landlord_user
    )

    @log2 = ServiceUsageLog.create!(
      room: @room2,
      service: @service2,
      service_variant: @variant2,
      service_name: @service2.name,
      unit: @variant2.human_unit,
      unit_price: @variant2.fee,
      prev_reading: 10,
      latest_reading: 25,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by: @landlord_user,
      submitted_by: @landlord_user
    )

    @log_prev = ServiceUsageLog.create!(
      room: @room1,
      service: @service1,
      service_variant: @variant1,
      service_name: @service1.name,
      unit: @variant1.human_unit,
      unit_price: @variant1.fee,
      prev_reading: 50,
      latest_reading: 100,
      billing_month: @prev_month,
      start_date: @prev_month.beginning_of_month,
      end_date: @prev_month.end_of_month,
      is_confirmed: true,
      confirmed_at: Time.current,
      submitted_by: @landlord_user
    )
  end

  test "filters by month" do
    results = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { month: @billing_month.strftime("%Y-%m") }
    )
    assert_includes results, @log1
    assert_includes results, @log2
    assert_not_includes results, @log_prev
  end

  test "filters by room" do
    results = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { room_id: @room1.id }
    )
    assert_includes results, @log1
    assert_includes results, @log_prev
    assert_not_includes results, @log2
  end

  test "filters by service" do
    results = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { service_id: @service2.id }
    )
    assert_includes results, @log2
    assert_not_includes results, @log1
  end

  test "filters by status unconfirmed" do
    results = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { status: "unconfirmed" }
    )
    assert_includes results, @log1
    assert_not_includes results, @log2
    assert_not_includes results, @log_prev
  end

  test "filters by status confirmed" do
    results = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { status: "confirmed" }
    )
    assert_includes results, @log2
    assert_includes results, @log_prev
    assert_not_includes results, @log1
  end

  test "scopes to dedicated room and supports pagination" do
    results = LandlordServiceUsageLogsFilter.call(
      house: @house,
      room: @room1,
      params: { page: 1, per_page: 1 }
    )
    assert_equal 1, results.length
    assert_equal 2, results.total_pages
  end

  test "filters by floor" do
    floor2 = @house.floors.create!(name: "Tầng 2", position: 2)
    room3 = floor2.rooms.create!(name: "201", max_slots: 2, tenants_count: 1, area: 25)
    room3.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    log3 = ServiceUsageLog.create!(
      room: room3,
      service: @service1,
      service_variant: @variant1,
      service_name: @service1.name,
      unit: @variant1.human_unit,
      unit_price: @variant1.fee,
      prev_reading: 10,
      latest_reading: 20,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: true,
      submitted_by: @landlord_user
    )

    results_floor1 = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { floor_id: @floor.id }
    )
    assert_includes results_floor1, @log1
    assert_includes results_floor1, @log2
    assert_not_includes results_floor1, log3

    results_floor2 = LandlordServiceUsageLogsFilter.call(
      house: @house,
      params: { floor_id: floor2.id }
    )
    assert_includes results_floor2, log3
    assert_not_includes results_floor2, @log1
    assert_not_includes results_floor2, @log2
  end
end
