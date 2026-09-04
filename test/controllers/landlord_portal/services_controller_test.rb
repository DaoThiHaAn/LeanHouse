require "test_helper"

class LandlordPortal::ServicesControllerTest < ActionDispatch::IntegrationTest
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
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 25)
    @service = @house.services.create!(name: "Điện", note: "Giá sinh hoạt")
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

  test "index renders successfully for landlord" do
    sign_in_as(@landlord_user)
    get landlord_house_services_path(@house)
    assert_response :success
    assert_select "h1", /#{I18n.t('page_titles.service_mng')}/
    assert_select "#service_#{@service.id}"
    assert_select "button[data-bs-target='#serviceGuideModal']"
    assert_select "#serviceGuideModal"
  end

  test "show renders turbo frame partial when requested via turbo frame" do
    sign_in_as(@landlord_user)
    get landlord_house_service_path(@house, @service), headers: { "Turbo-Frame" => "service_workspace" }
    assert_response :success
    assert_select "turbo-frame#service_workspace"
    assert_select ".service-workspace-container"
    assert_select "h2", /#{@service.name}/
  end

  test "create adds new service" do
    sign_in_as(@landlord_user)
    assert_difference -> { @house.services.count }, 1 do
      post landlord_house_services_path(@house), params: {
        service: { name: "Nước sinh hoạt", note: "Tính theo khối" }
      }
    end
    assert_redirected_to landlord_house_service_path(@house, Service.last)
  end

  test "update modifies service details" do
    sign_in_as(@landlord_user)
    patch landlord_house_service_path(@house, @service), params: {
      service: { name: "Điện lưới", note: "Ghi chú mới" }
    }
    assert_redirected_to landlord_house_service_path(@house, @service)
    @service.reload
    assert_equal "Điện lưới", @service.name
    assert_equal "Ghi chú mới", @service.note
  end

  test "destroy removes service" do
    sign_in_as(@landlord_user)
    assert_difference -> { @house.services.count }, -1 do
      delete landlord_house_service_path(@house, @service)
    end
    assert_redirected_to landlord_house_services_path(@house)
  end
end
