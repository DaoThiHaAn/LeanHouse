# frozen_string_literal: true

require "test_helper"

class ServiceUsageLogCreatorTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}")
    @landlord = Landlord.find(@landlord_user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "Creator House",
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

    @vacant_room = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 0, area: 25)
    @vacant_room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @service = @house.services.create!(name: "Điện", note: "Điện sinh hoạt")
    @variant = @service.service_variants.create!(unit: "per_kwh", fee: 3500, is_real_time: true)
    @billing_month = Date.current.beginning_of_month
  end

  test "build_default initializes a ServiceUsageLog with room, variant, and previous reading" do
    prev_month = 1.month.ago.beginning_of_month
    ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: @service.name,
      unit: @variant.human_unit,
      unit_price: @variant.fee,
      prev_reading: 100,
      latest_reading: 250,
      billing_month: prev_month,
      start_date: prev_month.beginning_of_month,
      end_date: prev_month.end_of_month,
      is_confirmed: true,
      submitted_by: @landlord_user
    )

    log = ServiceUsageLogCreator.build_default(
      house: @house,
      room: @room,
      params: { billing_month: @billing_month.strftime("%Y-%m"), service_variant_id: @variant.id }
    )

    assert_equal @room, log.room
    assert_equal @variant, log.service_variant
    assert_equal @service, log.service
    assert_equal 250, log.prev_reading
    assert_equal @billing_month, log.billing_month
  end

  test "call creates a confirmed log and sets submitted_by and confirmed_by" do
    log = ServiceUsageLogCreator.call(
      log_params: {
        room_id: @room.id,
        service_id: @service.id,
        service_variant_id: @variant.id,
        service_name: @service.name,
        unit: @variant.human_unit,
        unit_price: @variant.fee,
        billing_month: @billing_month,
        start_date: @billing_month.beginning_of_month,
        end_date: @billing_month.end_of_month,
        prev_reading: 100,
        latest_reading: 210,
        is_confirmed: true
      },
      user: @landlord_user
    )

    assert log.persisted?
    assert log.is_confirmed?
    assert_equal @landlord_user, log.submitted_by
    assert_equal @landlord_user, log.confirmed_by
    assert_not_nil log.confirmed_at
  end

  test "call forces is_confirmed to true when room is vacant" do
    log = ServiceUsageLogCreator.call(
      log_params: {
        room_id: @vacant_room.id,
        service_id: @service.id,
        service_variant_id: @variant.id,
        service_name: @service.name,
        unit: @variant.human_unit,
        unit_price: @variant.fee,
        billing_month: @billing_month,
        start_date: @billing_month.beginning_of_month,
        end_date: @billing_month.end_of_month,
        prev_reading: 100,
        latest_reading: 120,
        is_confirmed: false
      },
      user: @landlord_user
    )

    assert log.persisted?
    assert log.is_confirmed?
    assert_equal @landlord_user, log.confirmed_by
  end

  test "call creates an unconfirmed log awaiting tenant reading and notifies active tenants" do
    tenant_user = create_tenant(tel: "092#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}")
    tenant = Tenant.find(tenant_user.id)
    @room.rental_unit.tenant_stays.create!(tenant: tenant, checkin_at: 1.month.ago, checkout_at: nil)

    assert_difference("Noticed::Event.count", 1) do
      log = ServiceUsageLogCreator.call(
        log_params: {
          room_id: @room.id,
          service_id: @service.id,
          service_variant_id: @variant.id,
          service_name: @service.name,
          unit: @variant.human_unit,
          unit_price: @variant.fee,
          billing_month: @billing_month,
          start_date: @billing_month.beginning_of_month,
          end_date: @billing_month.end_of_month,
          prev_reading: 100,
          latest_reading: nil,
          is_confirmed: false
        },
        user: @landlord_user
      )

      assert log.persisted?
      assert_not log.is_confirmed?
      assert_nil log.submitted_by
      assert_nil log.confirmed_by
    end
  end
end
