require "test_helper"

class LandlordPortal::ContractsControllerTest < ActionDispatch::IntegrationTest
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
      checkin_at: Date.current,
      has_contract: true
    )

    @contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "Standard Contract",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: Date.current,
      due_date: Date.current + 6.months,
      deposit_paid: true,
      temp_resid_registered: false,
      note: "Initial note"
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @contract.save!
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

  test "landlord can view edit contract page" do
    sign_in_as(@landlord_user)

    get edit_landlord_house_contract_path(@house, @contract)
    assert_response :success
    assert_select "input[name='contract[start_date]'][disabled]"
    assert_select "input[name='contract[due_date]'][disabled]"
    assert_select "button[type='reset']"
    assert_select "[data-image-upload-target='fileCount']", text: "1"
  end

  test "landlord updates contract successfully" do
    sign_in_as(@landlord_user)

    patch landlord_house_contract_path(@house, @contract), params: {
      contract: {
        name: "Renamed by Landlord",
        landlord_citizen_id: "999888777666",
        tenant_citizen_id: "111222333444",
        deposit_paid: "0",
        note: "Modified via web form"
      }
    }

    assert_redirected_to landlord_house_contract_path(@house, @contract)
    @contract.reload
    assert_equal "Renamed by Landlord", @contract.name
    assert_equal "999888777666", @contract.landlord_citizen_id
    assert_equal "111222333444", @contract.tenant_citizen_id
    assert_equal false, @contract.deposit_paid
    assert_equal "Modified via web form", @contract.note
  end

  test "landlord update fails with invalid attributes" do
    sign_in_as(@landlord_user)

    patch landlord_house_contract_path(@house, @contract), params: {
      contract: {
        name: "",
        landlord_citizen_id: "invalid_id"
      }
    }

    assert_response :unprocessable_entity
    assert_not_equal "", @contract.reload.name
  end
end
