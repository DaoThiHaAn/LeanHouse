require "test_helper"

class VehicleDeletionTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Le",
      tel: "0907654321",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Tenant Rd",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Happy House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @vehicle = Vehicle.create!(
      tenant: @tenant,
      house: @house,
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "Vision"
    )
  end

  test "deletes vehicle and sends notification to tenant and landlord" do
    assert_difference -> { Vehicle.count }, -1 do
      assert_difference -> { Noticed::Notification.count }, 2 do
        VehicleDeletion.call(
          vehicle: @vehicle,
          actor_user: @landlord_user,
          reason: "Khách đã bán xe và không còn gửi tại nhà"
        )
      end
    end

    assert_not Vehicle.exists?(@vehicle.id)
    noti = Noticed::Notification.last
    assert_includes noti.event.params[:reason], "Khách đã bán xe"
  end

  test "raises error when reason is blank" do
    assert_raises(ActiveRecord::RecordInvalid) do
      VehicleDeletion.call(
        vehicle: @vehicle,
        actor_user: @tenant_user,
        reason: ""
      )
    end

    assert Vehicle.exists?(@vehicle.id)
  end
end
