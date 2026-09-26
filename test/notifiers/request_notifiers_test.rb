# frozen_string_literal: true

require "test_helper"

class RequestNotifiersTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901116677")
    @tenant_user = create_tenant(tel: "0902226677")

    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Request Noti House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 1, tenants_count: 1, area: 20.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @tenant_stay = TenantStay.create!(
      tenant: @tenant_user.tenant,
      rental_unit: @rental_unit,
      checkin_at: 1.month.ago,
      has_contract: true
    )

    @repair_request = RepairRequest.create!(title: "Sửa máy lạnh", content: "Máy lạnh không mát")
    @request = @tenant_user.tenant.requests.create!(
      house: @house,
      requestable: @repair_request
    )

    @vehicle_request = VehicleRequest.new(
      license_plate: "59A-12345",
      vehicle_type: "motorbike",
      consent_given_at: Time.current
    )
    @vehicle_request.vehicle_photo.attach(io: StringIO.new("vphoto"), filename: "v.jpg", content_type: "image/jpeg")
    @vehicle_request.registration_card_image.attach(io: StringIO.new("card"), filename: "c.jpg", content_type: "image/jpeg")
    @vehicle_request.save!

    @veh_req = @tenant_user.tenant.requests.create!(
      house: @house,
      requestable: @vehicle_request
    )

    @leave_request = LeaveHouseRequest.create!
    @leave_req = @tenant_user.tenant.requests.create!(
      house: @house,
      requestable: @leave_request
    )
  end

  test "RepairRequestCreatedNotifier delivers correct title and url to landlord and tenant" do
    RepairRequestCreatedNotifier.with(
      request: @request,
      tenant_name: @tenant_user.fullname,
      house_id: @house.id,
      house_name: @house.name,
      location: @tenant_stay.rental_unit.location_info,
      title: @repair_request.title
    ).deliver([ @landlord_user, @tenant_user ])

    landlord_noti = @landlord_user.notifications.last
    assert_not_nil landlord_noti
    assert_includes landlord_noti.url, "/landlord/requests"

    tenant_noti = @tenant_user.notifications.last
    assert_not_nil tenant_noti
    assert_includes tenant_noti.url, "/tenant/requests"
  end

  test "VehicleRequestCreatedNotifier delivers correct notification to landlord and tenant" do
    VehicleRequestCreatedNotifier.with(
      request: @veh_req,
      tenant_name: @tenant_user.fullname,
      house_name: @house.name,
      location: @tenant_stay.rental_unit.location_info,
      license_plate: @vehicle_request.license_plate
    ).deliver([ @landlord_user, @tenant_user ])

    assert @landlord_user.notifications.any?
    assert @tenant_user.notifications.any?
  end

  test "LeaveHouseRequestCreatedNotifier delivers correct notification" do
    LeaveHouseRequestCreatedNotifier.with(
      request: @leave_req,
      tenant_name: @tenant_user.fullname,
      house_name: @house.name,
      location: @tenant_stay.rental_unit.location_info
    ).deliver([ @landlord_user, @tenant_user ])

    assert @landlord_user.notifications.any?
    assert @tenant_user.notifications.any?
  end

  test "RequestResolvedNotifier delivers approval and rejection decisions" do
    RequestResolvedNotifier.with(
      request: @request,
      decision: "approved",
      house_name: @house.name,
      reason: nil
    ).deliver(@tenant_user)

    assert_includes @tenant_user.notifications.last.url, "/tenant/requests"

    RequestResolvedNotifier.with(
      request: @request,
      decision: "rejected",
      house_name: @house.name,
      reason: "Không hợp lệ"
    ).deliver(@tenant_user)

    assert @tenant_user.notifications.any?
  end
end
