require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      fullname: "Model Test User",
      tel: "0904445566",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 28.years.ago.to_date,
      address: "123 Test St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Model Test House",
      mode: :room,
      address_l1: "123 Test St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 20.0)

    @invoice = @house.invoices.create!(
      code: "HD-MODEL-TEST-001",
      title: "Tiền phòng",
      room: @room,
      created_by: @user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_000_000,
      total_amount: 2_000_000
    )
  end

  test "payment_method is nil when invoice is not paid" do
    assert_nil @invoice.payment_method
    assert_predicate @invoice, :pending?

    @invoice.payment_method = "cash"
    @invoice.save!
    # Callback forces payment_method to nil unless paid
    assert_nil @invoice.payment_method
  end

  test "mark_as_paid! sets payment_method, paid_at, paid_by and clears undo_reason" do
    @invoice.undo_reason = "Lý do cũ"
    @invoice.mark_as_paid!(by_user: @user, method: "cash")

    assert_predicate @invoice, :paid?
    assert_equal "cash", @invoice.payment_method
    assert_equal @user, @invoice.paid_by
    assert_equal "landlord", @invoice.paid_by_role
    assert_not_nil @invoice.paid_at
    assert_nil @invoice.undo_reason
  end

  test "undo_paid! clears paid_at and payment_method, sets undo_reason and appropriate status" do
    @invoice.mark_as_paid!(by_user: @user, method: "transfer")
    assert_predicate @invoice, :paid?

    @invoice.undo_paid!(by_user: @user, explanation: "Chưa nhận được tiền")

    assert_predicate @invoice, :pending? # due_date is in future
    assert_nil @invoice.paid_at
    assert_nil @invoice.payment_method
    assert_equal "Chưa nhận được tiền", @invoice.undo_reason
    assert_equal @user, @invoice.undone_by
    assert_includes @invoice.note, "Chưa nhận được tiền"
  end

  test "undo_paid! sets status to overdue if due_date is in past" do
    @invoice.update!(due_date: Date.current - 2.days)
    @invoice.mark_as_paid!(by_user: @user, method: "transfer")

    @invoice.undo_paid!(by_user: @user, explanation: "Hủy thanh toán quá hạn")

    assert_predicate @invoice, :overdue?
    assert_nil @invoice.payment_method
  end

  test "undo_paid! requires an explanation" do
    @invoice.mark_as_paid!(by_user: @user, method: "transfer")

    assert_raises(ArgumentError) do
      @invoice.undo_paid!(by_user: @user, explanation: "")
    end
  end

  test "paid invoice cannot be updated with new attributes" do
    @invoice.mark_as_paid!(by_user: @user, method: "transfer")
    assert_predicate @invoice, :paid?

    @invoice.title = "Tiêu đề mới sau khi đã thanh toán"
    assert_not @invoice.valid?
    assert_includes @invoice.errors[:base], I18n.t("invoice.errors.cannot_update_paid")

    assert_raises(ActiveRecord::RecordInvalid) do
      @invoice.save!
    end
  end

  test "paid invoice cannot be cancelled directly" do
    @invoice.mark_as_paid!(by_user: @user, method: "transfer")
    assert_predicate @invoice, :paid?

    assert_raises(ArgumentError) do
      @invoice.cancel!(@user)
    end

    @invoice.reload
    assert_predicate @invoice, :paid?
  end

  test "paid invoice can be updated after payment confirmation is undone" do
    @invoice.mark_as_paid!(by_user: @user, method: "transfer")
    assert_predicate @invoice, :paid?

    @invoice.undo_paid!(by_user: @user, explanation: "Cần chỉnh sửa lại tiền")
    assert_predicate @invoice, :pending?

    @invoice.update!(title: "Tiêu đề đã sửa sau khi hoàn tác")
    assert_equal "Tiêu đề đã sửa sau khi hoàn tác", @invoice.reload.title
  end

  test "generate_code formats prefix as HD followed by dd, mm, and yyyy based on creation date" do
    creation_date = Date.new(2026, 9, 26)
    code = Invoice.generate_code(@room, creation_date)

    # Prefix is HD26092026, room name cleaned (ROOM10), followed by 4 uppercase alphanumeric suffix
    assert_match(/\AHD26092026-ROOM10-[A-Z0-9]{4}\z/, code)

    # If created on 11th of September 2026:
    code_today = Invoice.generate_code(@room, Date.new(2026, 9, 11))
    assert_match(/\AHD11092026-ROOM10-[A-Z0-9]{4}\z/, code_today)
  end

  test "automatically sets transfer_note on validation if mode is system or default" do
    inv = @house.invoices.new(
      code: "HD-AUTO-NOTE-TEST",
      title: "Tiền phòng",
      room: @room,
      created_by: @user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending
    )
    assert inv.valid?
    assert_equal "HD-AUTO-NOTE-TEST", inv.transfer_note
  end

  test "sets transfer_note to nil when transfer_note_mode is none" do
    inv = @house.invoices.new(
      code: "HD-NONE-NOTE-TEST",
      title: "Tiền phòng",
      room: @room,
      created_by: @user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      transfer_note_mode: "none"
    )
    assert inv.valid?
    assert_nil inv.transfer_note
  end

  test "sets custom transfer_note when transfer_note_mode is custom" do
    inv = @house.invoices.new(
      code: "HD-CUSTOM-NOTE-TEST",
      title: "Tiền phòng",
      room: @room,
      created_by: @user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      transfer_note_mode: "custom",
      transfer_note: "CUSTOM RENT PAYMENT"
    )
    assert inv.valid?
    assert_equal "CUSTOM RENT PAYMENT", inv.transfer_note
  end

  test "vietqr_url does not include addInfo when transfer_note is nil" do
    bank = Bank.find_or_create_by!(code: "VCB", bin: "970436", short_name: "Vietcombank", name: "Vietcombank")
    bank_account = BankAccount.create!(
      landlord: @landlord,
      bank: bank,
      account_number: "0123456789",
      account_holder: "TEST USER"
    )
    @invoice.update_column(:transfer_note, nil)
    @invoice.reload

    url = @invoice.vietqr_url(bank_account)
    assert_not_includes url, "addInfo="
  end

  test "invoice automatically generates payos_order_code on create" do
    assert @invoice.payos_order_code.present?
    assert @invoice.payos_order_code.is_a?(Integer)
  end

  test "vietqr_url uses payos description when bank account is configured for payOS" do
    mb_bank = Bank.find_or_create_by!(code: "MB", bin: "970422", short_name: "MB", name: "MB Bank")
    payos_account = BankAccount.create!(
      landlord: @landlord,
      bank: mb_bank,
      account_number: "0987654321",
      account_holder: "PAYOS LANDLORD",
      payos_enabled: true,
      payos_client_id: "client-id",
      payos_api_key: "api-key",
      payos_checksum_key: "checksum-key"
    )

    url = @invoice.vietqr_url(payos_account)
    assert_includes url, "HD%20#{@invoice.payos_order_code}"
  end
end
