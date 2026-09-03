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
end
