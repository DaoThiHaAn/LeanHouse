require "test_helper"

class InvoicesHelperTest < ActionView::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Chủ Nhà Test",
      tel: "0911000222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Đường Test",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)
    @house = @landlord.houses.create!(
      name: "Nhà Test Helper",
      address_l1: "456 Đường Helper",
      address_l2: "Phường 1",
      address_l3: "Quận 1",
      floors_count: 1,
      inv_creation_date: 1,
      mode: :room
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(name: "101", area: 25, max_slots: 2)

    @tenant_user = User.create!(
      fullname: "Khách Thuê Test",
      tel: "0922000333",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "789 Đường Khách",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)
  end

  test "invoice_status_badge renders correct badge for all statuses" do
    # Paid
    paid_inv = @house.invoices.create!(
      code: "HD-PAID-01",
      title: "Hóa đơn đã trả",
      room: @room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :paid,
      subtotal: 100_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 100_000
    )
    badge = invoice_status_badge(paid_inv)
    assert_includes badge, "invoice-badge-paid"
    assert_includes badge, "check_circle"
    assert_includes badge, I18n.t("invoice.status.paid")

    # Pending and not overdue
    pending_inv = @house.invoices.create!(
      code: "HD-PEND-01",
      title: "Hóa đơn chờ",
      room: @room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 100_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 100_000
    )
    badge = invoice_status_badge(pending_inv)
    assert_includes badge, "invoice-badge-pending"
    assert_includes badge, "hourglass_top"
    assert_includes badge, I18n.t("invoice.status.waiting_payment")

    # Pending and overdue
    overdue_inv = @house.invoices.create!(
      code: "HD-OVER-01",
      title: "Hóa đơn quá hạn",
      room: @room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current - 2.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 100_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 100_000
    )
    badge = invoice_status_badge(overdue_inv)
    assert_includes badge, "invoice-badge-overdue"
    assert_includes badge, "error"
    assert_includes badge, I18n.t("invoice.status.overdue")

    # Cancelled
    cancelled_inv = @house.invoices.create!(
      code: "HD-CANC-01",
      title: "Hóa đơn hủy",
      room: @room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :cancelled,
      subtotal: 100_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 100_000
    )
    badge = invoice_status_badge(cancelled_inv)
    assert_includes badge, "invoice-badge-cancelled"
    assert_includes badge, "cancel"
    assert_includes badge, I18n.t("invoice.status.cancelled")
  end

  test "invoice_type_badge renders correct badge for room and individual" do
    room_inv = @house.invoices.build(invoice_type: :room)
    badge = invoice_type_badge(room_inv)
    assert_includes badge, "invoice-badge-room"
    assert_includes badge, I18n.t("invoice.mode_room")

    ind_inv = @house.invoices.build(invoice_type: :individual, tenant: @tenant)
    badge = invoice_type_badge(ind_inv)
    assert_includes badge, "invoice-badge-individual"
    assert_includes badge, @tenant_user.fullname
  end
end
