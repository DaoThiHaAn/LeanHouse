# frozen_string_literal: true

require "application_system_test_case"

class ServiceUsageLogsTest < ApplicationSystemTestCase
  setup do
    @landlord_user = create_landlord(tel: "0905112233", password: "Password123")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Điện Nước",
      mode: :room,
      address_l1: "100 Cách Mạng Tháng 8",
      address_l2: "Phường 7",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P.301", area: 24.0, max_slots: 2, tenants_count: 1)

    @tenant_user = create_tenant(tel: "0906112233", password: "Password123", fullname: "Vo Van Khach")
    @tenant = @tenant_user.tenant

    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )

    @service = @house.services.create!(name: "Điện sinh hoạt")
    @variant = @service.service_variants.create!(
      unit: :per_kwh,
      fee: 3_500,
      is_real_time: true
    )
    @room.room_services.create!(service_variant: @variant)

    @usage_log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: "Điện sinh hoạt",
      unit: "kWh",
      unit_price: 3_500,
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      prev_reading: 120,
      latest_reading: nil,
      is_confirmed: false
    )
  end

  test "tenant can view unconfirmed meter reading and preview uploaded photo via Stimulus file-preview controller" do
    sign_in_as(@tenant_user)
    visit edit_tenant_service_usage_log_path(@usage_log)

    assert_selector "input[name='service_usage_log[latest_reading]']", wait: 5
    fill_in "service_usage_log[latest_reading]", with: 165

    photo_path = Rails.root.join("test/fixtures/files/normal.png")
    attach_file "service_usage_log[reading_photo]", photo_path, make_visible: true

    # Stimulus file-preview controller reveals the preview container
    assert_selector "[data-file-preview-target='container']:not(.d-none)", wait: 5

    find("button[type='submit']").click
    assert_text I18n.t("invoice.submit_reading_success"), wait: 5

    @usage_log.reload
    assert_equal 165, @usage_log.latest_reading
    assert_equal 45, @usage_log.usage_quantity
  end
end
