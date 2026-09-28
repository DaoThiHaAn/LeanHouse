# frozen_string_literal: true

require "application_system_test_case"

class LandlordPortalTest < ApplicationSystemTestCase
  setup do
    @landlord_user = create_landlord(tel: "0903334444", password: "Password123", fullname: "Nguyen Van Chu Tro")
    @landlord = @landlord_user.landlord

    @house_room = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Ánh Dương",
      mode: :room,
      address_l1: "12 Nguyễn Huệ",
      address_l2: "Phường Bến Nghé",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 5
    )
    @floor1 = @house_room.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room101 = @floor1.rooms.create!(name: "P.101", area: 25.0, max_slots: 2, tenants_count: 1)

    @house_bed = House.create!(
      landlord: @landlord,
      name: "Ký Túc Xá Xanh",
      mode: :bed,
      address_l1: "45 Lê Lợi",
      address_l2: "Phường Bến Thành",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 10
    )
    @bed_floor = @house_bed.floors.create!(name: "Tầng KTX 1", position: 1, rooms_count: 1)
    @bed_room = @bed_floor.rooms.create!(name: "KTX-01", area: 35.0, max_slots: 4, tenants_count: 0)

    @tenant_user = create_tenant(tel: "0906667777", password: "Password123", fullname: "Le Thi Khach Thue")
    @tenant = @tenant_user.tenant

    @rental_unit = @room101.rental_unit || @room101.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )

    @invoice = @house_room.invoices.create!(
      room: @room101,
      created_by: @landlord_user,
      code: "HD-SYS-101",
      title: "Hóa đơn tháng hiện tại",
      invoice_type: :room,
      billing_month: Date.current.beginning_of_month,
      due_date: 7.days.from_now.to_date,
      status: :pending,
      subtotal: 3_500_000,
      total_amount: 3_500_000
    )

    @repair_req = RepairRequest.create!(
      title: "Hỏng vòi nước bồn rửa",
      content: "Nước rò rỉ liên tục dưới gầm bồn rửa chén."
    )
    @request = Request.create!(
      tenant: @tenant,
      house: @house_room,
      requestable: @repair_req,
      status: :pending
    )
  end

  test "landlord dashboard displays overall statistics and filters by selected house" do
    sign_in_as(@landlord_user)
    visit landlord_dashboard_path

    assert_selector "select[name='house_id']", wait: 5
    assert_text(/Nhà Trọ Ánh Dương/i)
    assert_text(/Ký Túc Xá Xanh/i)

    select "Nhà Trọ Ánh Dương", from: "house_id"
    assert_selector "select[name='house_id']"
    assert_text(/Nhà Trọ Ánh Dương/i)
  end

  test "landlord can view room management for room-mode house and switch tabs in bed-mode house" do
    sign_in_as(@landlord_user)

    visit landlord_house_rooms_path(@house_room)
    assert_selector "h1", text: /Nhà Trọ Ánh Dương/i, wait: 5
    assert_text(/P\.101/i)

    visit landlord_house_rooms_path(@house_bed)
    assert_selector "h1", text: /Ký Túc Xá Xanh/i, wait: 5
    assert_selector "#houseTabs button[data-bs-target='#rooms-pane']"
    assert_selector "#houseTabs button[data-bs-target='#beds-pane']"

    find("#houseTabs button[data-bs-target='#beds-pane']").click
    assert_selector "#beds-pane.active", wait: 5
  end

  test "landlord can browse house invoices and open creation guide modal" do
    sign_in_as(@landlord_user)
    visit landlord_house_invoices_path(@house_room)

    assert_text "HD-SYS-101", wait: 5
    assert_selector "button[data-bs-target='#invoiceCreationGuideModal']"

    find("button[data-bs-target='#invoiceCreationGuideModal']").click
    assert_selector "#invoiceCreationGuideModal", visible: true, wait: 5
  end

  test "landlord can view and filter tenant requests in request handling page" do
    sign_in_as(@landlord_user)
    visit landlord_requests_path

    assert_selector "form.request-form", wait: 5
    assert_selector "select[name='house_id']"
    assert_selector "select[name='status']"
    assert_text "Yêu cầu sửa chữa"
    assert_text "Le Thi Khach Thue"
  end
end
