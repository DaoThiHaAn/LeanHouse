# frozen_string_literal: true

require "test_helper"

class HousesHelperTest < ActionView::TestCase
  include ApplicationHelper
  include HousesHelper
  include RequestsHelper

  setup do
    @landlord_user = create_landlord(tel: "0906661111")
    @tenant_user = create_tenant(tel: "0906662222")

    @room_house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Room Mode House",
      mode: :room,
      address_l1: "1 St",
      address_l2: "W1",
      address_l3: "D1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @room_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 0)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, area: 25.0)
    @room.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)

    @bed_house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Bed Mode House",
      mode: :bed,
      address_l1: "2 St",
      address_l2: "W2",
      address_l3: "D2",
      floors_count: 1,
      inv_creation_date: 1
    )
    @bed_room = @bed_house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 0).rooms.create!(name: "201", max_slots: 4, area: 25.0)
  end

  test "house_mode, house_mode_icon, occupied_rate_format, house_mode_badge, floor_general_details" do
    assert_includes house_mode(@room_house), "("
    assert_includes house_mode(@bed_house), "("
    assert_equal "living", house_mode_icon(@room_house)
    assert_equal "bed", house_mode_icon(@bed_house)
    assert_includes occupied_rate_format(@room_house), "/"
    assert_not_empty house_mode_badge(@room_house)
    assert_not_empty house_mode_badge(@bed_house)
    assert_includes floor_general_details(@floor), @floor.title_name
  end

  test "room_rent_display covers room mode and bed mode with 0, uniform, and varied bed rents" do
    assert_includes room_rent_display(@room_house, @room), "3,500,000"

    empty_room = @floor.rooms.create!(name: "102", max_slots: 2, area: 20.0)
    assert_equal "-", room_rent_display(@room_house, empty_room)

    # Bed house with no beds
    assert_equal "-", room_rent_display(@bed_house, @bed_room)

    # Bed house with uniform bed rents
    b1 = @bed_room.beds.create!(name: "1")
    b1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    b2 = @bed_room.beds.create!(name: "2")
    b2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    assert_includes room_rent_display(@bed_house, @bed_room.reload), "1,500,000"

    # Bed house with varied bed rents
    b2.rental_unit.update!(rent: 2_000_000)
    assert_includes room_rent_display(@bed_house, @bed_room.reload), "-"
  end

  test "requests_helper filter options and badges" do
    opts = tenant_house_filter_options([ @room_house, @bed_house ], @room_house)
    assert_equal 3, opts.size

    t_years = tenant_year_filter_options(@tenant_user.tenant)
    assert t_years.any?
    assert tenant_year_filter_options(nil).any?

    l_houses = landlord_house_filter_options([ @room_house ])
    assert_equal 2, l_houses.size

    l_years = landlord_year_filter_options(@landlord_user.landlord)
    assert l_years.any?
    assert landlord_year_filter_options(nil).any?
  end

  test "services_helper methods" do
    extend ServicesHelper

    fake_variant = Struct.new(:is_real_time?, :unit, :human_unit).new(true, :per_room, "phòng")
    assert_includes service_calculation_type_badge(fake_variant), "speed"
    fake_variant.send(:[]=, :is_real_time?, false)
    assert_includes service_calculation_type_badge(fake_variant), "lock"

    [ :per_room, :per_month, :per_person, :per_item, :kwh ].each do |u|
      v = Struct.new(:unit, :human_unit).new(u, u.to_s)
      assert_kind_of Float, fixed_service_applied_quantity(@room, v, vehicle_count: 2)
      assert_kind_of String, fixed_service_quantity_display(@room, v, vehicle_count: 2)
    end
  end
end
