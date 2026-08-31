require "test_helper"

class LandlordPortal::ServiceVariantsControllerTest < ActionDispatch::IntegrationTest
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
      name: "Happy House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room1 = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 25)
    @room2 = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 0, area: 25)

    @service = @house.services.create!(name: "Điện")
    @variant = @service.service_variants.create!(fee: 3500, unit: :per_kwh, is_real_time: true)
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

  test "create adds variant to service" do
    sign_in_as(@landlord_user)
    assert_difference -> { @service.service_variants.count }, 1 do
      post landlord_house_service_service_variants_path(@house, @service), params: {
        service_variant: { fee: 4000, unit: "per_kwh", is_real_time: "1" }
      }
    end
    assert_redirected_to landlord_house_service_path(@house, @service)
  end

  test "update modifies variant meta" do
    sign_in_as(@landlord_user)
    patch landlord_house_service_service_variant_path(@house, @service, @variant), params: {
      service_variant: { fee: 3800, unit: "per_kwh", is_real_time: "1" },
      notify_tenants: "0"
    }
    assert_redirected_to landlord_house_service_path(@house, @service)
    @variant.reload
    assert_equal 3800, @variant.fee
  end

  test "edit_application renders room checklist" do
    sign_in_as(@landlord_user)
    get edit_application_landlord_house_service_service_variant_path(@house, @service, @variant),
        headers: { "Turbo-Frame" => "service_variant_modal" }
    assert_response :success
    assert_select "#editApplicationModal"
    assert_select "input[type=checkbox][value='#{@room1.id}']"
  end

  test "update_application syncs room assignments" do
    sign_in_as(@landlord_user)
    patch update_application_landlord_house_service_service_variant_path(@house, @service, @variant), params: {
      room_ids: [ @room1.id, @room2.id ],
      notify_tenants: "0"
    }
    assert_redirected_to landlord_house_service_path(@house, @service)
    assert_equal [ @room1.id, @room2.id ].sort, @variant.rooms.pluck(:id).sort
  end

  test "destroy removes variant and responds with stream or redirect" do
    sign_in_as(@landlord_user)
    assert_difference -> { @service.service_variants.count }, -1 do
      delete landlord_house_service_service_variant_path(@house, @service, @variant)
    end
    assert_redirected_to landlord_house_service_path(@house, @service)
  end
end
