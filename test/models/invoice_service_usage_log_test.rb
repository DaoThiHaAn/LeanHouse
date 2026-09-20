# frozen_string_literal: true

require "test_helper"

class InvoiceServiceUsageLogTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      fullname: "Nguyen Van Landlord",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Test St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "M2M Test House",
      mode: :room,
      address_l1: "123 Test St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Floor 1", position: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 20.0)
    @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @service = @house.services.create!(name: "Điện", note: "Điện sinh hoạt")
    @variant = @service.service_variants.create!(unit: "per_kwh", fee: 3500, is_real_time: true)
    @billing_month = Date.current.beginning_of_month

    @log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: @service.name,
      unit: "kWh",
      unit_price: 3500,
      billing_month: @billing_month,
      start_date: @billing_month,
      end_date: @billing_month.end_of_month,
      prev_reading: 100,
      latest_reading: 150,
      is_confirmed: true
    )

    @invoice1 = Invoice.create!(
      code: "INV-TEST-001",
      title: "Bill 1",
      house: @house,
      room: @room,
      created_by: @user,
      invoice_type: "individual",
      status: :pending,
      billing_month: @billing_month,
      start_date: @billing_month,
      end_date: @billing_month.end_of_month,
      due_date: Date.current + 5.days,
      subtotal: 100_000,
      total_amount: 100_000
    )

    @invoice2 = Invoice.create!(
      code: "INV-TEST-002",
      title: "Bill 2",
      house: @house,
      room: @room,
      created_by: @user,
      invoice_type: "individual",
      status: :pending,
      billing_month: @billing_month,
      start_date: @billing_month,
      end_date: @billing_month.end_of_month,
      due_date: Date.current + 5.days,
      subtotal: 100_000,
      total_amount: 100_000
    )
  end

  test "links invoice and service_usage_log" do
    join = InvoiceServiceUsageLog.create!(
      invoice: @invoice1,
      service_usage_log: @log
    )
    assert join.persisted?
    assert_includes @invoice1.service_usage_logs, @log
    assert_includes @log.invoices, @invoice1
    assert @log.billed?
  end

  test "allows multiple invoices to link to the same service_usage_log" do
    @invoice1.service_usage_logs << @log
    @invoice2.service_usage_logs << @log

    assert_equal 2, @log.invoices.count
    assert_includes @log.invoices, @invoice1
    assert_includes @log.invoices, @invoice2
    assert @log.billed?
  end

  test "enforces uniqueness of invoice and service_usage_log pair" do
    InvoiceServiceUsageLog.create!(invoice: @invoice1, service_usage_log: @log)
    duplicate = InvoiceServiceUsageLog.new(invoice: @invoice1, service_usage_log: @log)
    assert_not duplicate.valid?
  end

  test "destroying one invoice preserves log.billed? if another invoice remains" do
    @invoice1.service_usage_logs << @log
    @invoice2.service_usage_logs << @log

    assert_equal 2, @log.invoices.count

    @invoice1.destroy!
    @log.reload
    assert_equal 1, @log.invoices.count
    assert @log.billed?

    @invoice2.destroy!
    @log.reload
    assert_equal 0, @log.invoices.count
    assert_not @log.billed?
  end
end
