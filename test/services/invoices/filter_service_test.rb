# frozen_string_literal: true

require "test_helper"

class Invoices::FilterServiceTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Filter Test Landlord",
      tel: "0901234999",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Filter House",
      mode: :room,
      address_l1: "123 St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "T1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P101", max_slots: 2, tenants_count: 0, area: 25.0)

    @billing_month = Date.current.beginning_of_month

    # 1. in_term & pending
    @inv_pending_in_term = @house.invoices.create!(
      code: "HD-PEND-INTERM",
      title: "Pending In Term",
      room: @room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 3.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 1_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 1_000_000
    )

    # 2. overdue & pending
    @inv_pending_overdue = @house.invoices.create!(
      code: "HD-PEND-OVERDUE",
      title: "Pending Overdue",
      room: @room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current - 2.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 2_000_000
    )

    # 3. paid (in_term)
    @inv_paid = @house.invoices.create!(
      code: "HD-PAID",
      title: "Paid Invoice",
      room: @room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 2.days,
      invoice_type: :room,
      status: :paid,
      subtotal: 3_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_000_000,
      paid_at: Time.current
    )

    # 4. cancelled
    @inv_cancelled = @house.invoices.create!(
      code: "HD-CANCELLED",
      title: "Cancelled Invoice",
      room: @room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 2.days,
      invoice_type: :room,
      status: :cancelled,
      subtotal: 4_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 4_000_000
    )
  end

  test "filters by term_status in_term" do
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { term_status: "in_term" }
    )

    assert_includes result, @inv_pending_in_term
    assert_includes result, @inv_paid
    assert_not_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_cancelled
  end

  test "filters by term_status overdue" do
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { term_status: "overdue" }
    )

    assert_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_pending_in_term
    assert_not_includes result, @inv_paid
    assert_not_includes result, @inv_cancelled
  end

  test "filters by payment_status pending" do
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { payment_status: "pending" }
    )

    assert_includes result, @inv_pending_in_term
    assert_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_paid
    assert_not_includes result, @inv_cancelled
  end

  test "filters by payment_status paid" do
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { payment_status: "paid" }
    )

    assert_includes result, @inv_paid
    assert_not_includes result, @inv_pending_in_term
    assert_not_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_cancelled
  end

  test "filters by payment_status cancelled" do
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { payment_status: "cancelled" }
    )

    assert_includes result, @inv_cancelled
    assert_not_includes result, @inv_pending_in_term
    assert_not_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_paid
  end

  test "combines term_status and payment_status" do
    # pending & in_term
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { term_status: "in_term", payment_status: "pending" }
    )
    assert_includes result, @inv_pending_in_term
    assert_not_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_paid

    # pending & overdue
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { term_status: "overdue", payment_status: "pending" }
    )
    assert_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_pending_in_term
    assert_not_includes result, @inv_paid
  end

  test "supports legacy status param for backward compatibility" do
    # status: overdue
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { status: "overdue" }
    )
    assert_includes result, @inv_pending_overdue
    assert_not_includes result, @inv_pending_in_term

    # status: paid
    result = Invoices::FilterService.call(
      house: @house,
      billing_month: @billing_month,
      params: { status: "paid" }
    )
    assert_includes result, @inv_paid
    assert_not_includes result, @inv_pending_in_term
  end
end
