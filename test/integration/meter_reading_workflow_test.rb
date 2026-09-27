# frozen_string_literal: true

require "test_helper"

class MeterReadingWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = create_landlord(tel: "0907008009", password: "Password123")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Chỉ Số Điện",
      mode: :room,
      address_l1: "22 Hai Bà Trưng",
      address_l2: "Phường Bến Nghé",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P.205", area: 25.0, max_slots: 2, tenants_count: 1)

    @tenant_user = create_tenant(tel: "0908009010", password: "Password123")
    @tenant = @tenant_user.tenant

    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 2.months.ago,
      checkout_at: nil
    )

    @service = @house.services.create!(name: "Nước máy")
    @variant = @service.service_variants.create!(
      unit: :per_m3,
      fee: 18_000,
      is_real_time: true
    )
    @room.room_services.create!(service_variant: @variant)

    @usage_log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: "Nước máy",
      unit: "m3",
      unit_price: 18_000,
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      prev_reading: 50,
      latest_reading: nil,
      is_confirmed: false
    )
  end

  test "tenant submits meter reading with photo and landlord confirms the reading for invoicing" do
    # Step 1: Tenant logs in and submits meter reading + photo
    post handle_login_path, params: {
      user: { tel: @tenant_user.tel, password: "Password123", role: "tenant" }
    }

    photo_upload = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/normal.png"),
      "image/png"
    )

    patch tenant_service_usage_log_path(@usage_log), params: {
      service_usage_log: {
        latest_reading: 62,
        reading_photo: photo_upload
      }
    }

    @usage_log.reload
    assert_equal 62, @usage_log.latest_reading
    assert_equal 12, @usage_log.usage_quantity
    assert @usage_log.reading_photo.attached?
    refute @usage_log.is_confirmed?

    delete logout_path

    # Step 2: Landlord logs in and confirms the tenant's meter reading
    post handle_login_path, params: {
      user: { tel: @landlord_user.tel, password: "Password123", role: "landlord" }
    }

    patch confirm_landlord_house_service_usage_log_path(@house, @usage_log)
    @usage_log.reload

    assert @usage_log.is_confirmed?
    assert_equal @landlord_user.id, @usage_log.confirmed_by_id
  end
end
