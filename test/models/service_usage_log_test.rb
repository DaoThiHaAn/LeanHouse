require "test_helper"

class ServiceUsageLogTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      fullname: "Meter Test Landlord",
      tel: "0901234599",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Meter Test St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Meter Test House",
      mode: :room,
      address_l1: "123 Meter Test St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 20.0)

    @service = @house.services.create!(name: "Điện", note: "Điện sinh hoạt")
    @variant = @service.service_variants.create!(
      unit: "per_kwh",
      fee: 3500,
      is_real_time: true
    )
    @billing_month = Date.current.beginning_of_month
  end

  test "valid when latest_reading is greater than prev_reading" do
    log = ServiceUsageLog.new(
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

    assert log.valid?
    log.save!
    assert_equal 50, log.usage_quantity
  end

  test "valid when latest_reading equals prev_reading" do
    log = ServiceUsageLog.new(
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
      latest_reading: 100,
      is_confirmed: true
    )

    assert log.valid?
    log.save!
    assert_equal 0, log.usage_quantity
  end

  test "invalid when latest_reading is less than prev_reading" do
    log = ServiceUsageLog.new(
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
      latest_reading: 99,
      is_confirmed: true
    )

    assert_not log.valid?
    assert log.errors[:latest_reading].any?
    assert_includes log.errors.full_messages.to_s, "100"
  end

  test "valid when unconfirmed and latest_reading is nil" do
    log = ServiceUsageLog.new(
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
      latest_reading: nil,
      is_confirmed: false
    )

    assert log.valid?
  end

  test "invalid when latest_reading is non-integer" do
    log = ServiceUsageLog.new(
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
      latest_reading: 105.5,
      is_confirmed: true
    )

    assert_not log.valid?
    assert log.errors[:latest_reading].any?
  end
end
