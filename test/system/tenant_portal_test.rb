# frozen_string_literal: true

require "application_system_test_case"

class TenantPortalTest < ApplicationSystemTestCase
  setup do
    @landlord_user = create_landlord(tel: "0904445555", password: "Password123")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Bình Yên",
      mode: :room,
      address_l1: "88 Điện Biên Phủ",
      address_l2: "Phường Đa Kao",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P.202", area: 22.0, max_slots: 2, tenants_count: 1)

    @tenant_user = create_tenant(tel: "0907778888", password: "Password123", fullname: "Pham Van Nguoi Thue")
    @tenant = @tenant_user.tenant

    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 3_200_000, deposit: 3_200_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 2.months.ago,
      checkout_at: nil
    )

    @room_invoice = @house.invoices.create!(
      room: @room,
      created_by: @landlord_user,
      code: "HD-TENANT-ROOM-01",
      title: "Tiền phòng tháng 9",
      invoice_type: :room,
      billing_month: Date.current.beginning_of_month,
      due_date: 5.days.from_now.to_date,
      status: :pending,
      subtotal: 3_200_000,
      total_amount: 3_200_000
    )

    @custom_invoice = @house.invoices.create!(
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      code: "HD-TENANT-CUSTOM-02",
      title: "Phí làm lại thẻ từ",
      invoice_type: :custom,
      billing_month: Date.current.beginning_of_month,
      due_date: 5.days.from_now.to_date,
      status: :pending,
      subtotal: 100_000,
      total_amount: 100_000
    )
  end

  test "tenant dashboard displays active room stay info and statistics" do
    sign_in_as(@tenant_user)
    visit tenant_dashboard_path

    assert_selector ".tenant-dashboard", wait: 5
    assert_text(/Nhà Trọ Bình Yên/i)
    assert_text(/P\.202/i)
  end

  test "tenant can view room invoices and switch to custom invoices tab" do
    sign_in_as(@tenant_user)
    visit tenant_invoices_path

    assert_selector "#tenant_invoices_table", wait: 5
    assert_text "HD-TENANT-ROOM-01"

    find("a.log-tab[href*='tab=custom']").click
    assert_text "HD-TENANT-CUSTOM-02", wait: 5
  end

  test "tenant with active stay can access request creation dropdown and filter requests" do
    sign_in_as(@tenant_user)
    visit tenant_requests_path

    assert_selector ".request.main-container", wait: 5
    assert_selector "button.dropdown-toggle", text: I18n.t("request.create")

    find("button.dropdown-toggle", text: I18n.t("request.create")).click
    assert_selector "a[href='#{new_tenant_vehicle_request_path}']", visible: true
    assert_selector "a[href='#{new_tenant_repair_request_path}']", visible: true

    # Filter by status and verify clear button visibility toggle
    assert_selector "form.request-form"
    select Request.status_options.first.first, from: "status"
    assert_selector "[data-filter-form-target='clearButton']", visible: true, wait: 5

    find("[data-filter-form-target='clearButton'] button").click
    assert_selector "[data-filter-form-target='clearButton'].d-none", visible: :all, wait: 5
  end
end
