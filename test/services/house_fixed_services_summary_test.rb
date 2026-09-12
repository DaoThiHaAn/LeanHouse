# frozen_string_literal: true

require "test_helper"

class HouseFixedServicesSummaryTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord House Summary Test",
      tel: "0911223399",
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
      name: "House Summary Test House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 2,
      inv_creation_date: 1
    )
    @floor1 = @house.floors.create!(name: "Tầng 1", position: 1)
    @floor2 = @house.floors.create!(name: "Tầng 2", position: 2)

    @room1 = @floor1.rooms.create!(name: "101", max_slots: 5, tenants_count: 2, area: 20)
    @room1.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @room2 = @floor2.rooms.create!(name: "201", max_slots: 5, tenants_count: 1, area: 20)
    @room2.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)

    # Fixed services
    @svc_wifi = @house.services.create!(name: "Wifi")
    @var_wifi = @svc_wifi.service_variants.create!(unit: "per_room", fee: 50_000, is_real_time: false)

    @svc_cleaning = @house.services.create!(name: "Vệ sinh")
    @var_cleaning = @svc_cleaning.service_variants.create!(unit: "per_person", fee: 30_000, is_real_time: false)

    RoomService.create!(room: @room1, service_variant: @var_wifi, service: @svc_wifi)
    RoomService.create!(room: @room1, service_variant: @var_cleaning, service: @svc_cleaning)

    RoomService.create!(room: @room2, service_variant: @var_wifi, service: @svc_wifi)

    @billing_month = Date.current.beginning_of_month
  end

  test "calculates draft items across rooms accurately" do
    summary = HouseFixedServicesSummary.call(house: @house, billing_month: @billing_month)

    assert_equal 3, summary.items.size
    assert_equal 2, summary.total_rooms_count
    assert_equal 3, summary.draft_count
    assert_equal 0, summary.billed_count

    # Room 101: wifi (1 * 50_000 = 50_000), cleaning (2 * 30_000 = 60_000)
    # Room 201: wifi (1 * 50_000 = 50_000)
    # Total: 160_000
    assert_equal 160_000, summary.total_amount

    r1_wifi = summary.items.find { |it| it.room == @room1 && it.variant == @var_wifi }
    assert_not_nil r1_wifi
    assert_equal "1", r1_wifi.quantity_formatted
    assert_equal 50_000, r1_wifi.amount
    assert r1_wifi.draft?

    r1_cleaning = summary.items.find { |it| it.room == @room1 && it.variant == @var_cleaning }
    assert_not_nil r1_cleaning
    assert_equal "2", r1_cleaning.quantity_formatted
    assert_equal 60_000, r1_cleaning.amount
    assert r1_cleaning.draft?
  end

  test "filters by floor and room" do
    # Filter by floor 1
    summary_f1 = HouseFixedServicesSummary.call(
      house: @house,
      billing_month: @billing_month,
      params: { floor_id: @floor1.id }
    )
    assert_equal 2, summary_f1.items.size
    assert summary_f1.items.all? { |it| it.room.floor_id == @floor1.id }

    # Filter by room 201
    summary_r2 = HouseFixedServicesSummary.call(
      house: @house,
      billing_month: @billing_month,
      params: { room_id: @room2.id }
    )
    assert_equal 1, summary_r2.items.size
    assert_equal @room2, summary_r2.items.first.room
  end

  test "filters by service and status" do
    summary_wifi = HouseFixedServicesSummary.call(
      house: @house,
      billing_month: @billing_month,
      params: { service_id: @svc_wifi.id }
    )
    assert_equal 2, summary_wifi.items.size
    assert summary_wifi.items.all? { |it| it.service == @svc_wifi }

    summary_draft = HouseFixedServicesSummary.call(
      house: @house,
      billing_month: @billing_month,
      params: { status: "draft" }
    )
    assert_equal 3, summary_draft.items.size

    summary_billed = HouseFixedServicesSummary.call(
      house: @house,
      billing_month: @billing_month,
      params: { status: "billed" }
    )
    assert_equal 0, summary_billed.items.size
  end

  test "handles billed and waived items when invoice exists" do
    invoice = @room1.invoices.create!(
      house: @house,
      billing_month: @billing_month,
      status: :pending,
      invoice_type: "room",
      code: "HD-TEST-101",
      created_by: @landlord_user,
      title: "Hóa đơn phòng 101",
      subtotal: 50_000,
      total_amount: 50_000,
      due_date: Date.current + 5.days
    )
    # Only billed Wifi in invoice, waived Cleaning
    invoice.invoice_items.create!(
      service_variant: @var_wifi,
      name: "Wifi",
      unit: "per_room",
      unit_price: 50_000,
      quantity: 1,
      amount: 50_000,
      item_type: :fixed_service
    )

    summary = HouseFixedServicesSummary.call(house: @house, billing_month: @billing_month)

    r1_wifi = summary.items.find { |it| it.room == @room1 && it.variant == @var_wifi }
    assert r1_wifi.billed?
    assert_equal invoice, r1_wifi.invoice

    r1_cleaning = summary.items.find { |it| it.room == @room1 && it.variant == @var_cleaning }
    assert r1_cleaning.waived?
    assert_equal 0, r1_cleaning.amount

    # Room 201 still has no invoice, so draft
    r2_wifi = summary.items.find { |it| it.room == @room2 && it.variant == @var_wifi }
    assert r2_wifi.draft?

    assert_equal 1, summary.billed_count
    assert_equal 1, summary.waived_count
    assert_equal 1, summary.draft_count
  end
end
