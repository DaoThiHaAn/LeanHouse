# frozen_string_literal: true

require "test_helper"

class PaymentOrderTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      fullname: "Test Landlord",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Street",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "Sunrise House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 25)
    @invoice = @house.invoices.create!(
      room: @room,
      created_by: @user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      title: "Tiền phòng",
      subtotal: 3_000_000,
      total_amount: 3_000_000,
      status: "pending",
      code: "HD-TEST-PAYMENT-ORDER"
    )
  end

  test "validates presence of provider and order_code" do
    order = PaymentOrder.new(invoice: @invoice, provider: nil)
    assert_not order.valid?
    assert order.errors[:order_code].present?
    assert order.errors[:provider].present?

    order.order_code = 123456789
    order.provider = "payos"
    assert order.valid?
  end

  test "validates uniqueness of order_code" do
    PaymentOrder.create!(invoice: @invoice, provider: "payos", order_code: 999888777)
    duplicate = PaymentOrder.new(invoice: @invoice, provider: "payos", order_code: 999888777)
    assert_not duplicate.valid?
    assert duplicate.errors[:order_code].present?
  end

  test "generate_order_code generates a 9-digit integer" do
    code = PaymentOrder.generate_order_code
    assert code.is_a?(Integer)
    assert_operator code, :>=, 100_000_000
    assert_operator code, :<=, 999_999_999
  end

  test "scopes filter by provider and status" do
    order = PaymentOrder.create!(invoice: @invoice, provider: "payos", order_code: 111222333, status: "PENDING")
    assert_includes PaymentOrder.payos, order
    assert_includes PaymentOrder.pending, order
    assert_not_includes PaymentOrder.paid, order

    order.update!(status: "PAID")
    assert_includes PaymentOrder.paid, order
    assert_not_includes PaymentOrder.pending, order
  end
end
