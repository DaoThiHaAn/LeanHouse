require "test_helper"

class ServiceDesignTest < ActiveSupport::TestCase
  test "a room can apply a service variant through room services" do
    user = User.create!(
      fullname: "Test User",
      password: "Password1",
      password_confirmation: "Password1",
      tel: "0123456789",
      sex: "M",
      bday: 20.years.ago.to_date,
      address: "Test Address",
      role: :landlord,
      terms_accepted: true
    )

    landlord = user.create_landlord!(id: user.id)
    house = landlord.houses.create!(
      name: "Test House",
      mode: :room,
      address_l1: "Address 1",
      address_l2: "Address 2",
      address_l3: "Address 3",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "1", rooms_count: 1)
    room = floor.rooms.create!(name: "1", max_slots: 1, tenants_count: 0, area: 20.0)
    service = house.services.create!(name: "Wifi")
    variant = service.service_variants.create!(fee: 1000, unit: :per_month, is_real_time: false)

    room_service = room.room_services.create!(service_variant: variant)

    assert_includes room.service_variants, variant
    assert_equal service, room_service.service
    assert_equal [ room_service ], variant.room_services.to_a
  end
end
