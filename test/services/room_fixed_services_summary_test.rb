# frozen_string_literal: true

require "test_helper"

class RoomFixedServicesSummaryTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Summary Test",
      tel: "0911223344",
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
      name: "Summary Test House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 5, tenants_count: 1, area: 20)
  end

  test "calculates draft quantities correctly based on unit types" do
    @room.update!(tenants_count: 3)

    # Per room
    svc1 = @house.services.create!(name: "Internet")
    v1 = svc1.service_variants.create!(unit: "per_room", fee: 100_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v1, service: svc1)

    # Per person
    svc2 = @house.services.create!(name: "Vệ sinh")
    v2 = svc2.service_variants.create!(unit: "per_person", fee: 30_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v2, service: svc2)

    # Per item (vehicles)
    svc3 = @house.services.create!(name: "Gửi xe máy")
    v3 = svc3.service_variants.create!(unit: "per_item", fee: 50_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v3, service: svc3)

    # Tenant with 2 vehicles
    tenant_user = User.create!(
      tel: "0988776655",
      password: "Password123",
      password_confirmation: "Password123",
      fullname: "Nguyen Van A",
      role: :tenant,
      sex: "male",
      bday: 20.years.ago.to_date,
      address: "123 Test",
      tel_verified_at: Time.current
    )
    tenant = Tenant.find_or_create_by!(id: tenant_user.id)
    rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 1_000_000, deposit: 1_000_000)
    rental_unit.tenant_stays.create!(tenant: tenant, checkin_at: 1.month.ago)

    Vehicle.create!(house: @house, tenant: tenant, vehicle_type: :motorbike, license_plate: "29A-12345")
    Vehicle.create!(house: @house, tenant: tenant, vehicle_type: :motorbike, license_plate: "29A-67890")

    summary = RoomFixedServicesSummary.call(room: @room, billing_month: Date.current)

    assert_nil summary.active_invoice
    assert_equal false, summary.has_active_invoice?
    assert_equal 3, summary.items.size

    item_room = summary.items.find { |i| i.variant.id == v1.id }
    assert_equal "1", item_room.quantity
    assert_equal 100_000, item_room.amount
    assert item_room.draft?

    item_person = summary.items.find { |i| i.variant.id == v2.id }
    assert_equal "3", item_person.quantity
    assert_equal 90_000, item_person.amount
    assert item_person.draft?

    item_item = summary.items.find { |i| i.variant.id == v3.id }
    assert_equal "2", item_item.quantity
    assert_equal 100_000, item_item.amount
    assert item_item.draft?

    assert_equal 290_000, summary.total_amount
  end

  test "uses actual billed quantities and flags waived services when active invoice exists" do
    svc_wifi = @house.services.create!(name: "Wifi")
    v_wifi = svc_wifi.service_variants.create!(unit: "per_room", fee: 100_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v_wifi, service: svc_wifi)

    svc_trash = @house.services.create!(name: "Rác")
    v_trash = svc_trash.service_variants.create!(unit: "per_room", fee: 30_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v_trash, service: svc_trash)

    billing_month = Date.current.beginning_of_month
    invoice = Invoice.create!(
      code: "INV-ACTIVE-01",
      title: "HĐ tháng",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: billing_month,
      due_date: billing_month + 10.days,
      subtotal: 100_000,
      total_amount: 100_000,
      status: :pending
    )
    # Only Wifi is billed, Trash is waived (not present in invoice)
    invoice.invoice_items.create!(
      service_variant: v_wifi,
      item_type: "fixed_service",
      name: "Wifi",
      unit: "phòng",
      unit_price: 100_000,
      quantity: 1.0,
      amount: 100_000
    )

    summary = RoomFixedServicesSummary.call(room: @room, billing_month: billing_month)

    assert_equal invoice, summary.active_invoice
    assert_equal true, summary.has_active_invoice?
    assert_equal 2, summary.items.size

    item_wifi = summary.items.find { |i| i.variant.id == v_wifi.id }
    assert item_wifi.billed?
    assert_equal "1", item_wifi.quantity
    assert_equal 100_000, item_wifi.amount

    item_trash = summary.items.find { |i| i.variant.id == v_trash.id }
    assert item_trash.waived?
    assert_equal "0", item_trash.quantity
    assert_equal 0, item_trash.amount

    assert_equal 100_000, summary.total_amount
  end

  test "paginates items correctly" do
    15.times do |i|
      svc = @house.services.create!(name: "Dịch vụ #{i + 1}")
      v = svc.service_variants.create!(unit: "per_room", fee: 10_000 * (i + 1), is_real_time: false)
      RoomService.create!(room: @room, service_variant: v, service: svc)
    end

    summary_p1 = RoomFixedServicesSummary.call(room: @room, billing_month: Date.current, page: 1, per_page: 10)
    assert_equal 15, summary_p1.items.size
    assert_equal 10, summary_p1.paginated_items.size
    assert_equal 2, summary_p1.paginated_items.total_pages
    assert_equal 1, summary_p1.paginated_items.current_page

    summary_p2 = RoomFixedServicesSummary.call(room: @room, billing_month: Date.current, page: 2, per_page: 10)
    assert_equal 15, summary_p2.items.size
    assert_equal 5, summary_p2.paginated_items.size
    assert_equal 2, summary_p2.paginated_items.current_page
  end

  test "excludes services added after the billing month" do
    past_month = 2.months.ago.beginning_of_month

    svc_old = @house.services.create!(name: "Dịch vụ cũ")
    v_old = svc_old.service_variants.create!(unit: "per_room", fee: 50_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v_old, service: svc_old, created_at: 3.months.ago)

    svc_new = @house.services.create!(name: "Dịch vụ mới")
    v_new = svc_new.service_variants.create!(unit: "per_room", fee: 70_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v_new, service: svc_new, created_at: 1.day.ago)

    summary = RoomFixedServicesSummary.call(room: @room, billing_month: past_month)
    assert_equal 1, summary.items.size
    assert_equal "Dịch vụ cũ", summary.items.first.name
  end

  test "tenant parameter scopes vehicle count to only tenant's vehicles" do
    svc_vehicle = @house.services.create!(name: "Gửi xe")
    v_vehicle = svc_vehicle.service_variants.create!(unit: "per_item", fee: 50_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v_vehicle, service: svc_vehicle)

    # Tenant 1 with 2 vehicles
    t1_user = User.create!(tel: "0981111111", password: "Password123", password_confirmation: "Password123", fullname: "Tenant Mot", role: :tenant, sex: "male", bday: 20.years.ago.to_date, address: "123 Test", tel_verified_at: Time.current)
    tenant1 = Tenant.find_or_create_by!(id: t1_user.id)
    rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 1_000_000, deposit: 1_000_000)
    rental_unit.tenant_stays.create!(tenant: tenant1, checkin_at: 1.month.ago)
    Vehicle.create!(house: @house, tenant: tenant1, vehicle_type: :motorbike, license_plate: "29A-11111")
    Vehicle.create!(house: @house, tenant: tenant1, vehicle_type: :motorbike, license_plate: "29A-22222")

    # Tenant 2 with 1 vehicle
    t2_user = User.create!(tel: "0982222222", password: "Password123", password_confirmation: "Password123", fullname: "Tenant Hai", role: :tenant, sex: "female", bday: 21.years.ago.to_date, address: "456 Test", tel_verified_at: Time.current)
    tenant2 = Tenant.find_or_create_by!(id: t2_user.id)
    rental_unit.tenant_stays.create!(tenant: tenant2, checkin_at: 3.months.ago, checkout_at: 1.month.ago)
    Vehicle.create!(house: @house, tenant: tenant2, vehicle_type: :motorbike, license_plate: "29B-33333")

    summary_t1 = RoomFixedServicesSummary.call(room: @room, billing_month: Date.current, tenant: tenant1)
    summary_t2 = RoomFixedServicesSummary.call(room: @room, billing_month: Date.current, tenant: tenant2)
    summary_all = RoomFixedServicesSummary.call(room: @room, billing_month: Date.current)

    item_t1 = summary_t1.items.find { |i| i.variant.id == v_vehicle.id }
    item_t2 = summary_t2.items.find { |i| i.variant.id == v_vehicle.id }
    item_all = summary_all.items.find { |i| i.variant.id == v_vehicle.id }

    assert_equal "2", item_t1.quantity
    assert_equal 100_000, item_t1.amount

    assert_equal "1", item_t2.quantity
    assert_equal 50_000, item_t2.amount

    assert_equal "3", item_all.quantity
    assert_equal 150_000, item_all.amount
  end

  test "tenant parameter finds tenant's individual active invoice" do
    svc = @house.services.create!(name: "Dịch vụ phòng")
    v = svc.service_variants.create!(unit: "per_room", fee: 100_000, is_real_time: false)
    RoomService.create!(room: @room, service_variant: v, service: svc)

    t1_user = User.create!(tel: "0983333333", password: "Password123", password_confirmation: "Password123", fullname: "Tenant Indiv Mot", role: :tenant, sex: "male", bday: 20.years.ago.to_date, address: "123 Test", tel_verified_at: Time.current)
    tenant1 = Tenant.find_or_create_by!(id: t1_user.id)
    t2_user = User.create!(tel: "0984444444", password: "Password123", password_confirmation: "Password123", fullname: "Tenant Indiv Hai", role: :tenant, sex: "female", bday: 20.years.ago.to_date, address: "123 Test", tel_verified_at: Time.current)
    tenant2 = Tenant.find_or_create_by!(id: t2_user.id)

    billing_month = Date.current.beginning_of_month
    invoice_t1 = Invoice.create!(
      code: "INV-T1-01",
      title: "HĐ cá nhân T1",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "individual",
      tenant: tenant1,
      billing_month: billing_month,
      due_date: billing_month + 10.days,
      subtotal: 100_000,
      total_amount: 100_000,
      status: :pending
    )
    invoice_t1.invoice_items.create!(
      service_variant: v,
      item_type: "fixed_service",
      name: "Dịch vụ phòng",
      unit: "phòng",
      unit_price: 100_000,
      quantity: 1.0,
      amount: 100_000
    )

    summary_t1 = RoomFixedServicesSummary.call(room: @room, billing_month: billing_month, tenant: tenant1)
    summary_t2 = RoomFixedServicesSummary.call(room: @room, billing_month: billing_month, tenant: tenant2)

    assert_equal invoice_t1, summary_t1.active_invoice
    assert_equal true, summary_t1.has_active_invoice?
    assert summary_t1.items.first.billed?

    assert_nil summary_t2.active_invoice
    assert_equal false, summary_t2.has_active_invoice?
    assert summary_t2.items.first.draft?
  end
end
