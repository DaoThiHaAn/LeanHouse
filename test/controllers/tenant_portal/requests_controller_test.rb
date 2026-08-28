require "test_helper"

class TenantPortal::RequestsControllerTest < ActionDispatch::IntegrationTest
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

    @vehicle_req = VehicleRequest.new(
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "Vision",
      consent_given_at: Time.current
    )
    @vehicle_req.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg.png",
      content_type: "image/png"
    )
    @vehicle_req.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo.png",
      content_type: "image/png"
    )
    @vehicle_req.save!

    @tenant_request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @vehicle_req,
      status: :pending
    )
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

  test "tenant can view requests index page" do
    sign_in_as(@tenant_user)

    get tenant_requests_path
    assert_response :success
    assert_select "h1", text: I18n.t("request.mine")
    assert_select "form[action='#{filtered_tenant_requests_path}']"
    assert_select "select[name='house_id']"
    assert_select "select[name='month']"
    assert_select "select[name='year']"
    assert_select "select[name='status']"
    assert_select "select[name='request_type']"
    assert_select "turbo-frame#requests_table"
  end

  test "filtered returns request table partial with records" do
    sign_in_as(@tenant_user)

    get filtered_tenant_requests_path, headers: { "Turbo-Frame" => "requests_table" }
    assert_response :success
    assert_select "turbo-frame#requests_table"
    assert_select "table tbody tr", count: 1
    assert_select "a[data-turbo-frame='request_detail_modal']", text: I18n.t("request.vehicle_register")
  end

  test "unlinked tenant can still view requests index page" do
    @tenant_stay.destroy!
    sign_in_as(@tenant_user)

    get tenant_requests_path
    assert_response :success
    assert_select "h1", text: I18n.t("request.mine")
  end

  test "tenant can view request detail in modal frame" do
    sign_in_as(@tenant_user)

    get tenant_request_path(@tenant_request), headers: { "Turbo-Frame" => "request_detail_modal" }
    assert_response :success
    assert_select "turbo-frame#request_detail_modal"
    assert_select "#requestDetailModal"
    assert_select "#requestDetailModalLabel", text: /#{@tenant_request.id}/
    assert_includes response.body, "59A-12345"
    assert_includes response.body, "Honda"
    assert_includes response.body, "Vision"
  end
end
