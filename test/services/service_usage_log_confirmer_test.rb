# frozen_string_literal: true

require "test_helper"

class ServiceUsageLogConfirmerTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}")
    @landlord = Landlord.find(@landlord_user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "Confirmer House",
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
    @variant = @service.service_variants.create!(unit: "per_kwh", fee: 3500, is_real_time: true)
    @billing_month = Date.current.beginning_of_month

    @log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: @service.name,
      unit: @variant.human_unit,
      unit_price: @variant.fee,
      prev_reading: 100,
      latest_reading: 180,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: false,
      submitted_by: @landlord_user
    )
  end

  test "confirm marks a single log as confirmed and sets confirmed_by and confirmed_at" do
    ServiceUsageLogConfirmer.confirm(log: @log, user: @landlord_user)

    @log.reload
    assert @log.is_confirmed?
    assert_equal @landlord_user, @log.confirmed_by
    assert_not_nil @log.confirmed_at
  end

  test "confirm notifies active staying tenants when present" do
    tenant_user = create_tenant(tel: "091#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}")
    tenant = Tenant.find(tenant_user.id)
    @room.rental_unit.tenant_stays.create!(tenant: tenant, checkin_at: 1.month.ago, checkout_at: nil)

    assert_difference("Noticed::Event.count", 1) do
      ServiceUsageLogConfirmer.confirm(log: @log, user: @landlord_user)
    end
  end

  test "confirm_all confirms all unconfirmed logs in scope and returns count" do
    room2 = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 1, area: 25)
    room2.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    log2 = ServiceUsageLog.create!(
      room: room2,
      service: @service,
      service_variant: @variant,
      service_name: @service.name,
      unit: @variant.human_unit,
      unit_price: @variant.fee,
      prev_reading: 50,
      latest_reading: 90,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: false,
      submitted_by: @landlord_user
    )

    count = ServiceUsageLogConfirmer.confirm_all(
      scope: @house.service_usage_logs.for_month(@billing_month),
      user: @landlord_user
    )

    assert_equal 2, count
    assert @log.reload.is_confirmed?
    assert log2.reload.is_confirmed?
  end
end
