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
    assert_includes badge, I18n.t("invoice.badge_representative")

    ind_inv = @house.invoices.build(invoice_type: :individual, tenant: @tenant)
    badge = invoice_type_badge(ind_inv)
    assert_includes badge, "invoice-badge-individual"
    assert_includes badge, I18n.t("invoice.badge_self_pay")
    assert_includes badge, @tenant_user.fullname

    custom_inv = @house.invoices.build(invoice_type: :custom, tenant: @tenant)
    badge = invoice_type_badge(custom_inv)
    assert_includes badge, "invoice-badge-custom"
    assert_includes badge, I18n.t("invoice.badge_custom")
    assert_includes badge, @tenant_user.fullname
  end

  test "invoice_term_badge renders in_term or overdue correctly" do
    in_term_inv = @house.invoices.build(
      status: :pending,
      due_date: Date.current + 5.days
    )
    badge = invoice_term_badge(in_term_inv)
    assert_includes badge, "invoice-badge-paid"
    assert_includes badge, I18n.t("invoice.status.in_term")

    overdue_inv = @house.invoices.build(
      status: :pending,
      due_date: Date.current - 1.day
    )
    badge = invoice_term_badge(overdue_inv)
    assert_includes badge, "invoice-badge-overdue"
    assert_includes badge, I18n.t("invoice.status.overdue")
  end

  test "invoice_payment_status_badge renders pure payment status without overdue override" do
    overdue_pending_inv = @house.invoices.build(
      status: :pending,
      due_date: Date.current - 1.day
    )
    badge = invoice_payment_status_badge(overdue_pending_inv)
    assert_includes badge, "invoice-badge-pending"
    assert_includes badge, "hourglass_top"
    assert_includes badge, I18n.t("invoice.status.pending")
    refute_includes badge, "invoice-badge-overdue"

    paid_inv = @house.invoices.build(status: :paid)
    badge = invoice_payment_status_badge(paid_inv)
    assert_includes badge, "invoice-badge-paid"
    assert_includes badge, I18n.t("invoice.status.paid")

    cancelled_inv = @house.invoices.build(status: :cancelled)
    badge = invoice_payment_status_badge(cancelled_inv)
    assert_includes badge, "invoice-badge-cancelled"
    assert_includes badge, I18n.t("invoice.status.cancelled")
  end

  test "invoice_header_badges renders both term badge and payment status badge" do
    inv = @house.invoices.build(
      status: :pending,
      due_date: Date.current + 5.days
    )
    badges = invoice_header_badges(inv)
    assert_includes badges, I18n.t("invoice.status.in_term")
    assert_includes badges, I18n.t("invoice.status.pending")
  end

  test "invoice_transfer_note_mode detects correct mode" do
    # nil or unpersisted invoice defaults to system
    assert_equal "system", invoice_transfer_note_mode(nil)
    new_inv = @house.invoices.build
    assert_equal "system", invoice_transfer_note_mode(new_inv)

    # explicit transfer_note_mode takes precedence
    new_inv.transfer_note_mode = "none"
    assert_equal "none", invoice_transfer_note_mode(new_inv)

    # persisted with blank transfer_note -> none
    persisted_inv = @house.invoices.create!(
      code: "HD-TN-01",
      title: "Hóa đơn test",
      room: @room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 100_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 100_000,
      transfer_note_mode: "none",
      transfer_note: nil
    )
    # persisted with blank transfer_note (no transfer_note_mode set) -> none
    persisted_inv.transfer_note_mode = nil
    assert_equal "none", invoice_transfer_note_mode(persisted_inv)

    # persisted with matching system template -> system
    expected_system = TransferNoteBuilder.build(@house.transfer_note_template, persisted_inv)
    persisted_inv.update_column(:transfer_note, expected_system)
    persisted_inv.transfer_note_mode = nil
    assert_equal "system", invoice_transfer_note_mode(persisted_inv)

    # persisted with custom note -> custom
    persisted_inv.update_column(:transfer_note, "CUSTOM_NOTE_123")
    persisted_inv.transfer_note_mode = nil
    assert_equal "custom", invoice_transfer_note_mode(persisted_inv)
  end

  test "invoice_custom_transfer_note_value returns transfer_note only when in custom mode" do
    persisted_inv = @house.invoices.build(transfer_note: "CUSTOM_NOTE_123")
    assert_equal "CUSTOM_NOTE_123", invoice_custom_transfer_note_value(persisted_inv, "custom")
    assert_equal "", invoice_custom_transfer_note_value(persisted_inv, "system")
    assert_equal "", invoice_custom_transfer_note_value(persisted_inv, "none")
  end

  test "transfer_note_mode_options returns 3 configured options" do
    options = transfer_note_mode_options
    assert_equal 3, options.length
    assert_equal [ "system", "custom", "none" ], options.map { |o| o[:value] }
  end

  test "invoice_target_name returns correct target name" do
    inv = @house.invoices.build(room: @room, invoice_type: :room)
    assert_equal "#{@room.title_name}, #{@floor.title_name}", invoice_target_name(inv)
    assert_nil invoice_target_name(nil)
  end

  test "invoice_target_info renders room title for room invoice" do
    inv = @house.invoices.build(room: @room, invoice_type: :room)
    result = invoice_target_info(inv)
    assert_includes result, "#{@room.title_name}, #{@floor.title_name}"
    assert_includes result, "fw-semibold text-dark"
  end

  test "invoice_target_info renders tenant name, room and tel for individual invoice" do
    inv = @house.invoices.build(room: @room, invoice_type: :individual, tenant: @tenant)
    result = invoice_target_info(inv)
    assert_includes result, @tenant_user.fullname
    assert_includes result, "#{@room.title_name}, #{@floor.title_name}"
    assert_includes result, @tenant_user.tel
  end

  test "invoice_target_info includes type badge when show_type_badge is true" do
    inv = @house.invoices.build(room: @room, invoice_type: :room)
    result = invoice_target_info(inv, show_type_badge: true)
    assert_includes result, "invoice-badge-room"
  end
end
