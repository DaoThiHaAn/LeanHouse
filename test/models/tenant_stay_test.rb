require "test_helper"

class TenantStayTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901231122")
    @tenant_user = create_tenant(tel: "0909881122")

    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Stay Test House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3000000, deposit: 3000000)

    @stay = TenantStay.create!(
      tenant: @tenant_user.tenant,
      rental_unit: @rental_unit,
      checkin_at: 1.month.ago,
      has_contract: true
    )
  end

  test "validates checkout_at is greater than or equal to checkin_at" do
    @stay.checkout_at = @stay.checkin_at - 1.day
    assert_not @stay.valid?
    assert @stay.errors[:checkout_at].present?

    @stay.checkout_at = Time.current
    assert @stay.valid?
  end

  test "staying scope returns only current occupants without checkout_at" do
    assert_includes TenantStay.staying, @stay

    @stay.update!(checkout_at: Time.current)
    assert_not_includes TenantStay.staying, @stay
  end
end
