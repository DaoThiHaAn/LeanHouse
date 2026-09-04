# frozen_string_literal: true

require "test_helper"

class LandlordPortal::ServiceUsageLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)
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
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25)
    @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @service = @house.services.create!(name: "Điện", note: "Điện sinh hoạt")
    @variant = @service.service_variants.create!(
      unit: "per_kwh",
      fee: 3500,
      is_real_time: true
    )
    @room_service = RoomService.create!(room: @room, service_variant: @variant, service: @service)

    @billing_month = Date.current.beginning_of_month
    @log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: @service.name,
      unit: @variant.human_unit,
      unit_price: @variant.fee,
      prev_reading: 100,
      latest_reading: 220,
      billing_month: @billing_month,
      start_date: @billing_month.beginning_of_month,
      end_date: @billing_month.end_of_month,
      is_confirmed: false,
      submitted_by: @landlord_user
    )

    sign_in_as(@landlord_user)
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "should get house service usage logs index" do
    get landlord_house_service_usage_logs_path(@house)
    assert_response :success
    assert_select "h2", text: /#{I18n.t('invoice.meter_logs_title')}/
  end

  test "should get house service usage logs index scoped to service" do
    get landlord_house_service_usage_logs_path(@house, service_id: @service.id)
    assert_response :success
    assert_select "nav[aria-label='breadcrumb']", text: /#{@service.name}/
    assert_select "h2", text: /#{@service.name}/
  end

  test "should get dedicated room service usage logs index" do
    get landlord_house_room_service_usage_logs_path(@house, @room)
    assert_response :success
    assert_select "h2", text: /#{@room.name}/
    assert_select "nav[aria-label='breadcrumb']"
  end

  test "should get filtered logs for house" do
    get filtered_landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
    assert_response :success
    assert_select "turbo-frame#logs_table"
  end

  test "should get filtered logs for room" do
    get filtered_landlord_house_service_usage_logs_path(@house, room_id: @room.id)
    assert_response :success
    assert_select "turbo-frame#room_logs_table"
  end

  test "should get new log form" do
    get new_landlord_house_service_usage_log_path(@house, room_id: @room.id)
    assert_response :success
  end

  test "should create service usage log" do
    assert_difference("ServiceUsageLog.count", 1) do
      post landlord_house_service_usage_logs_path(@house), params: {
        service_usage_log: {
          room_id: @room.id,
          service_id: @service.id,
          service_variant_id: @variant.id,
          service_name: @service.name,
          unit: @variant.human_unit,
          unit_price: @variant.fee,
          billing_month: @billing_month.next_month.strftime("%Y-%m"),
          start_date: @billing_month.next_month.beginning_of_month,
          end_date: @billing_month.next_month.end_of_month,
          prev_reading: 220,
          latest_reading: 350,
          is_confirmed: true
        }
      }
    end
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.next_month.strftime("%Y-%m"))
  end

  test "should confirm single log and lock tenant modifications" do
    assert_equal false, @log.is_confirmed?
    assert_equal true, @log.can_be_edited_by_tenant?

    patch confirm_landlord_house_service_usage_log_path(@house, @log)
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))

    @log.reload
    assert_equal true, @log.is_confirmed?
    assert_equal false, @log.can_be_edited_by_tenant?
  end

  test "should confirm all logs for room" do
    assert_equal false, @log.is_confirmed?

    patch confirm_all_landlord_house_room_service_usage_logs_path(@house, @room)
    assert_redirected_to landlord_house_room_service_usage_logs_path(@house, @room)

    @log.reload
    assert_equal true, @log.is_confirmed?
  end

  test "should confirm all logs for house" do
    assert_equal false, @log.is_confirmed?

    patch confirm_all_landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))

    @log.reload
    assert_equal true, @log.is_confirmed?
  end

  test "should allow landlord to update reading of unbilled log" do
    patch landlord_house_service_usage_log_path(@house, @log), params: {
      service_usage_log: {
        latest_reading: 235
      }
    }
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))

    @log.reload
    assert_equal 235, @log.latest_reading
    assert_equal 135, @log.usage_quantity
  end

  test "should destroy unbilled log" do
    assert_difference("ServiceUsageLog.count", -1) do
      delete landlord_house_service_usage_log_path(@house, @log)
    end
    assert_redirected_to landlord_house_service_usage_logs_path(@house, month: @billing_month.strftime("%Y-%m"))
  end
end
