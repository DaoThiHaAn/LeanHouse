# frozen_string_literal: true

require "test_helper"

class LandlordServiceUsageLogsIndexBuilderTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}")
    @landlord = Landlord.find(@landlord_user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "Builder House",
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

    @realtime_service = @house.services.create!(name: "Điện", note: "Điện")
    @realtime_variant = @realtime_service.service_variants.create!(unit: "per_kwh", fee: 3500, is_real_time: true)
    RoomService.create!(room: @room, service: @realtime_service, service_variant: @realtime_variant)

    @fixed_service = @house.services.create!(name: "Wifi", note: "Wifi")
    @fixed_variant = @fixed_service.service_variants.create!(unit: "per_month", fee: 100_000, is_real_time: false)
    RoomService.create!(room: @room, service: @fixed_service, service_variant: @fixed_variant)

    @billing_month = Date.current.beginning_of_month
    @log = ServiceUsageLog.create!(
      room: @room,
      service: @realtime_service,
      service_variant: @realtime_variant,
      service_name: @realtime_service.name,
      unit: @realtime_variant.human_unit,
      unit_price: @realtime_variant.fee,
      prev_reading: 100,
      latest_reading: 180,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: false,
      submitted_by: @landlord_user
    )
  end

  test "parse_month parses YYYY-MM strings and falls back to current month on invalid input" do
    assert_equal Date.new(2026, 5, 1), LandlordServiceUsageLogsIndexBuilder.parse_month("2026-05")
    assert_equal Date.current.beginning_of_month, LandlordServiceUsageLogsIndexBuilder.parse_month("")
    assert_equal Date.current.beginning_of_month, LandlordServiceUsageLogsIndexBuilder.parse_month("invalid-date")
  end

  test "for_house returns real_time index data by default and fixed data when tab=fixed" do
    realtime_data = LandlordServiceUsageLogsIndexBuilder.for_house(
      house: @house,
      billing_month: @billing_month,
      params: {}
    )
    assert_equal "real_time", realtime_data.current_tab
    assert_equal 1, realtime_data.unconfirmed_count
    assert_equal 1, realtime_data.fixed_services_count
    assert_includes realtime_data.logs, @log

    fixed_data = LandlordServiceUsageLogsIndexBuilder.for_house(
      house: @house,
      billing_month: @billing_month,
      params: { tab: "fixed" }
    )
    assert_equal "fixed", fixed_data.current_tab
    assert_not_nil fixed_data.fixed_services_summary
    assert_includes fixed_data.fixed_services, @fixed_service
  end

  test "for_room returns room index data for real_time and fixed tabs" do
    realtime_data = LandlordServiceUsageLogsIndexBuilder.for_room(
      house: @house,
      room: @room,
      billing_month: @billing_month,
      params: {}
    )
    assert_equal "real_time", realtime_data.current_tab
    assert_equal 1, realtime_data.unconfirmed_count
    assert_includes realtime_data.logs, @log

    fixed_data = LandlordServiceUsageLogsIndexBuilder.for_room(
      house: @house,
      room: @room,
      billing_month: @billing_month,
      params: { tab: "fixed" }
    )
    assert_equal "fixed", fixed_data.current_tab
    assert_not_nil fixed_data.fixed_services_summary
  end

  test "for_service defaults to real_time for real-time service and fixed for fixed service" do
    realtime_data = LandlordServiceUsageLogsIndexBuilder.for_service(
      house: @house,
      service: @realtime_service,
      billing_month: @billing_month,
      params: {}
    )
    assert_equal "real_time", realtime_data.current_tab
    assert_includes realtime_data.logs, @log

    fixed_data = LandlordServiceUsageLogsIndexBuilder.for_service(
      house: @house,
      service: @fixed_service,
      billing_month: @billing_month,
      params: {}
    )
    assert_equal "fixed", fixed_data.current_tab
    assert_not_nil fixed_data.fixed_services_summary
  end

  test "floor_and_room_options returns rooms, floors, options, and variant/occupancy maps" do
    options = LandlordServiceUsageLogsIndexBuilder.floor_and_room_options(house: @house)

    assert_includes options.rooms, @room
    assert_includes options.floors, @floor
    assert_equal [ @realtime_variant.id.to_s ], options.room_real_time_variant_ids[@room.id.to_s]
    assert_equal true, options.room_occupancy[@room.id.to_s]
  end
end
