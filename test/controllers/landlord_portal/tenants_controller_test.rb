require "test_helper"

class LandlordPortal::TenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord User",
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
      name: "Sunny House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room1 = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25)
    @rental_unit1 = @room1.create_rental_unit!(rent: 3000000, deposit: 3000000)

    @room2 = @floor.rooms.create!(name: "102", max_slots: 2, tenants_count: 0, area: 25)
    @rental_unit2 = @room2.create_rental_unit!(rent: 3000000, deposit: 3000000)

    @room3 = @floor.rooms.create!(name: "103", max_slots: 2, tenants_count: 0, area: 25)
    @rental_unit3 = @room3.create_rental_unit!(rent: 3000000, deposit: 3000000)

    # Tenant 1: with contract
    @tenant_user1 = User.create!(
      fullname: "Nguyen Van A",
      tel: "091#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 22.years.ago.to_date,
      address: "Tenant St",
      tel_verified_at: Time.current
    )
    @tenant1 = Tenant.find_or_create_by!(id: @tenant_user1.id)
    @stay1 = @tenant1.tenant_stays.create!(rental_unit: @rental_unit1, checkin_at: 1.month.ago, checkout_at: nil, has_contract: true)
    @contract1 = @house.contracts.build(
      tenant: @tenant1,
      landlord: @landlord,
      name: "HD-01",
      start_date: 1.month.ago.to_date,
      due_date: 5.months.from_now.to_date,
      tenant_citizen_id: "123456789012",
      landlord_citizen_id: "987654321098"
    )
    @contract1.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @contract1.save!

    # Tenant 2: unsigned contract
    @tenant_user2 = User.create!(
      fullname: "Tran Thi B",
      tel: "092#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 21.years.ago.to_date,
      address: "Tenant St 2",
      tel_verified_at: Time.current
    )
    @tenant2 = Tenant.find_or_create_by!(id: @tenant_user2.id)
    @stay2 = @tenant2.tenant_stays.create!(rental_unit: @rental_unit2, checkin_at: 2.days.ago, checkout_at: nil, has_contract: false)
    @room2.update!(tenants_count: 1)
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

  test "index renders summary stats and unsigned banner when unsigned tenants exist" do
    sign_in_as(@landlord_user)
    get landlord_house_tenants_path(@house)
    assert_response :success
    assert_select "#tenant_stats_grid"
    assert_select "#unsigned_tenants_section"
    assert_select "#unsigned_tenant_#{@tenant2.id}"
    assert_select "a[href*='#{landlord_requests_path(house_id: @house.id, status: :pending)}'][target='_blank']"
    assert_select "h1", /#{I18n.t('page_titles.tenant_mng')}/
  end

  test "unsigned banner is not rendered when there are no unsigned tenants" do
    @stay2.update!(has_contract: true)
    sign_in_as(@landlord_user)
    get landlord_house_tenants_path(@house)
    assert_response :success
    assert_select "#tenant_stats_grid"
    assert_select "#unsigned_tenants_section", count: 0
  end

  test "filtered returns tenant table partial" do
    sign_in_as(@landlord_user)
    get filtered_landlord_house_tenants_path(@house, query: "Nguyen")
    assert_response :success
    assert_includes response.body, "Nguyen Van A"
  end

  test "create_new renders successfully" do
    sign_in_as(@landlord_user)
    get landlord_house_create_new_tenant_path(@house)
    assert_response :success
    assert_select "form"
    assert_select "#floor_id"
  end

  test "destroy removes tenant and redirects to index" do
    sign_in_as(@landlord_user)
    delete landlord_house_tenant_path(@house, @tenant2)
    assert_redirected_to landlord_house_tenants_path(@house)
    assert_equal I18n.t("success_messages.tenant_removed"), flash[:notice]
  end

  test "destroy fails and redirects with alert when tenant has pending invoices" do
    sign_in_as(@landlord_user)

    @house.invoices.create!(
      code: "HD-PENDING-TENANT-02",
      title: "Hóa đơn test chưa thanh toán",
      room: @room2,
      tenant: @tenant2,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :custom,
      status: :pending,
      subtotal: 500_000,
      total_amount: 500_000
    )

    delete landlord_house_tenant_path(@house, @tenant2)
    assert_redirected_to landlord_house_tenants_path(@house)
    assert_equal I18n.t("errors.tenant_has_pending_invoices", count: 1), flash[:alert]
    assert_nil @stay2.reload.checkout_at
  end

  test "show renders tenant detail modal with citizen_id, staying info, and contract info" do
    sign_in_as(@landlord_user)
    get landlord_house_tenant_path(@house, @tenant1)
    assert_response :success
    assert_select "turbo-frame#tenant_detail_modal"
    assert_includes response.body, "Nguyen Van A"
    assert_includes response.body, "123456789012"
    assert_includes response.body, "HD-01"
  end

  test "execute_move moves tenant and redirects to index via html" do
    sign_in_as(@landlord_user)
    post move_landlord_house_tenant_path(@house, @tenant1), params: { rental_unit_id: @rental_unit3.id }
    assert_redirected_to landlord_house_tenants_path(@house)
    assert_equal I18n.t("success_messages.tenant_moved"), flash[:notice]
    assert_equal @rental_unit3, @tenant1.reload.current_stay.rental_unit
  end

  test "execute_move via turbo_stream replaces row, stats, unsigned banner, closes modal, and updates flash" do
    sign_in_as(@landlord_user)
    post move_landlord_house_tenant_path(@house, @tenant1), params: { rental_unit_id: @rental_unit3.id }, as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_select "turbo-stream[action='replace'][target='#{ActionView::RecordIdentifier.dom_id(@tenant1)}']"
    assert_select "turbo-stream[action='replace'][target='tenant_stats_grid']"
    assert_select "turbo-stream[action='update'][target='unsigned_tenants_wrapper']"
    assert_select "turbo-stream[action='append'][target='events']"
    assert_select "turbo-stream[action='update'][target='flash']"
    assert_equal @rental_unit3, @tenant1.reload.current_stay.rental_unit
  end

  test "execute_move failure via turbo_stream returns unprocessable_entity and updates flash" do
    sign_in_as(@landlord_user)
    post move_landlord_house_tenant_path(@house, @tenant1), params: { rental_unit_id: 999_999 }, as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action='update'][target='flash']"
    assert_equal I18n.t("errors.rental_unit_unavailable"), flash[:alert]
  end

  test "execute_move with end_contract=1 terminates the active contract and sets has_contract false on new stay" do
    sign_in_as(@landlord_user)
    post move_landlord_house_tenant_path(@house, @tenant1),
      params: { rental_unit_id: @rental_unit3.id, end_contract: "1" }
    assert_redirected_to landlord_house_tenants_path(@house)
    new_stay = @tenant1.reload.current_stay
    assert_equal @rental_unit3, new_stay.rental_unit
    assert_not new_stay.has_contract, "New stay should have has_contract=false when end_contract is checked"
    assert @contract1.reload.end_date.present?, "Contract should have an end_date set"
    assert_equal Date.current, @contract1.reload.end_date
  end

  test "execute_move without end_contract keeps contract intact on new stay" do
    sign_in_as(@landlord_user)
    post move_landlord_house_tenant_path(@house, @tenant1),
      params: { rental_unit_id: @rental_unit3.id }
    new_stay = @tenant1.reload.current_stay
    assert_equal @rental_unit3, new_stay.rental_unit
    assert new_stay.has_contract, "New stay should still have has_contract=true when end_contract is not checked"
    assert_nil @contract1.reload.end_date, "Contract should remain open when end_contract is not checked"
  end

  test "destroy via turbo_stream removes row, updates stats, unsigned banner, and flash" do
    sign_in_as(@landlord_user)
    delete landlord_house_tenant_path(@house, @tenant1), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_select "turbo-stream[action='remove'][target='#{ActionView::RecordIdentifier.dom_id(@tenant1)}']"
    assert_select "turbo-stream[action='replace'][target='tenant_stats_grid']"
    assert_select "turbo-stream[action='update'][target='unsigned_tenants_wrapper']"
    assert_select "turbo-stream[action='update'][target='flash']"
    assert_equal I18n.t("success_messages.tenant_removed"), flash[:notice]
  end

  test "destroy last tenant redirects to index even when requested as turbo_stream" do
    @stay2.update!(checkout_at: Time.current)
    @room2.update!(tenants_count: 0)

    sign_in_as(@landlord_user)
    delete landlord_house_tenant_path(@house, @tenant1), as: :turbo_stream
    assert_redirected_to landlord_house_tenants_path(@house)
  end

  test "destroy failure via turbo_stream returns unprocessable_entity and updates flash when pending invoices" do
    sign_in_as(@landlord_user)

    @house.invoices.create!(
      code: "HD-PENDING-TENANT-02-TURBO",
      title: "Hóa đơn test chưa thanh toán",
      room: @room2,
      tenant: @tenant2,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :custom,
      status: :pending,
      subtotal: 500_000,
      total_amount: 500_000
    )

    delete landlord_house_tenant_path(@house, @tenant2), as: :turbo_stream
    assert_response :unprocessable_entity
    assert_select "turbo-stream[action='update'][target='flash']"
    assert_equal I18n.t("errors.tenant_has_pending_invoices", count: 1), flash[:alert]
  end

  test "new renders link tenant modal" do
    sign_in_as(@landlord_user)
    get new_landlord_house_tenant_path(@house)
    assert_response :success
    assert_select "turbo-frame#new_tenant_modal"
    assert_select "form[action='#{landlord_house_tenant_available_path(@house)}']"
  end

  test "available returns unprocessable_entity with specific current house error when tenant is already staying in current house" do
    sign_in_as(@landlord_user)
    get landlord_house_tenant_available_path(@house), params: { tenant_link_form: { tel: @tenant_user1.tel } }
    assert_response :unprocessable_entity

    expected_location = @rental_unit1.location_info
    expected_msg = I18n.t("errors.tel_linked_current_house_with_location", location: expected_location)
    assert_includes response.body, expected_msg
  end

  test "available returns unprocessable_entity with other house error when tenant is staying in another house" do
    other_house = House.create!(
      landlord: @landlord,
      name: "Other House",
      mode: :room,
      address_l1: "999 Other St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = other_house.floors.create!(name: "Tầng 1", position: 1)
    room = floor.rooms.create!(name: "901", max_slots: 2, tenants_count: 1, area: 25)
    rental_unit = room.create_rental_unit!(rent: 3000000, deposit: 3000000)

    other_tenant_user = User.create!(
      fullname: "Other House Tenant",
      tel: "093#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "Other St",
      tel_verified_at: Time.current
    )
    other_tenant = Tenant.find_or_create_by!(id: other_tenant_user.id)
    other_tenant.tenant_stays.create!(rental_unit: rental_unit, checkin_at: 1.week.ago, checkout_at: nil)

    sign_in_as(@landlord_user)
    get landlord_house_tenant_available_path(@house), params: { tenant_link_form: { tel: other_tenant_user.tel } }
    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("errors.tel_linked")
  end

  test "available renders extended_new turbo_stream when tenant is valid and available" do
    free_tenant_user = User.create!(
      fullname: "Free Tenant",
      tel: "094#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 20.years.ago.to_date,
      address: "Free St",
      tel_verified_at: Time.current
    )
    Tenant.find_or_create_by!(id: free_tenant_user.id)

    sign_in_as(@landlord_user)
    get landlord_house_tenant_available_path(@house), params: { tenant_link_form: { tel: free_tenant_user.tel } }
    assert_response :success
    assert_select "turbo-stream[action='replace'][target='tenant_form']"
    assert_includes response.body, free_tenant_user.fullname
  end

  test "new when house is full via turbo_frame does not render modal and updates flash with house_full error" do
    @room1.update!(tenants_count: 2)
    @room2.update!(tenants_count: 2)
    @room3.update!(tenants_count: 2)
    assert @house.reload.full?

    sign_in_as(@landlord_user)
    get new_landlord_house_tenant_path(@house), headers: { "Turbo-Frame" => "new_tenant_modal" }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html; charset=utf-8", response.content_type
    assert_select "turbo-stream[action='update'][target='flash']"
    assert_select "#newTenantModal", count: 0
    assert_equal I18n.t("errors.house_full"), flash[:alert]
  end

  test "new when house is full via html redirects to index with house_full error" do
    @room1.update!(tenants_count: 2)
    @room2.update!(tenants_count: 2)
    @room3.update!(tenants_count: 2)
    assert @house.reload.full?

    sign_in_as(@landlord_user)
    get new_landlord_house_tenant_path(@house)
    assert_redirected_to landlord_house_tenants_path(@house)
    assert_equal I18n.t("errors.house_full"), flash[:alert]
  end

  test "create_new when house is full redirects to index with house_full error" do
    @room1.update!(tenants_count: 2)
    @room2.update!(tenants_count: 2)
    @room3.update!(tenants_count: 2)
    assert @house.reload.full?

    sign_in_as(@landlord_user)
    get landlord_house_create_new_tenant_path(@house)
    assert_redirected_to landlord_house_tenants_path(@house)
    assert_equal I18n.t("errors.house_full"), flash[:alert]
  end

  test "available when house is full redirects or updates flash with house_full error" do
    @room1.update!(tenants_count: 2)
    @room2.update!(tenants_count: 2)
    @room3.update!(tenants_count: 2)
    assert @house.reload.full?

    sign_in_as(@landlord_user)
    get landlord_house_tenant_available_path(@house), params: { tenant_link_form: { tel: "0901234567" } }
    assert_redirected_to landlord_house_tenants_path(@house)
    assert_equal I18n.t("errors.house_full"), flash[:alert]
  end
end
