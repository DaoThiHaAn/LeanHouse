require "test_helper"

class RepairRequestSubmissionTest < ActiveSupport::TestCase
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

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: Date.current
    )
  end

  test "creates repair request and request, then sends notifications" do
    assert_difference -> { RepairRequest.count }, 1 do
      assert_difference -> { Request.count }, 1 do
        assert_difference -> { Noticed::Notification.count }, 2 do
          RepairRequestSubmission.call(
            tenant: @tenant,
            house: @house,
            tenant_stay: @tenant_stay,
            params: {
              title: "Hỏng điều hòa",
              content: "Điều hòa phát ra tiếng kêu to và không mát"
            }
          )
        end
      end
    end

    request = Request.last
    assert_equal @tenant, request.tenant
    assert_equal @house, request.house
    assert_equal "pending", request.status
    assert_equal "RepairRequest", request.requestable_type

    repair_req = request.requestable
    assert_equal "Hỏng điều hòa", repair_req.title
    assert_equal "Điều hòa phát ra tiếng kêu to và không mát", repair_req.content
  end

  test "raises validation error on invalid params" do
    assert_raises(ActiveRecord::RecordInvalid) do
      RepairRequestSubmission.call(
        tenant: @tenant,
        house: @house,
        tenant_stay: @tenant_stay,
        params: {
          title: "",
          content: ""
        }
      )
    end
  end
end
