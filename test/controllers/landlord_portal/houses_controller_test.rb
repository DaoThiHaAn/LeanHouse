require "test_helper"

class LandlordPortal::HousesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Tran",
      tel: "0901112222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "female",
      bday: 32.years.ago.to_date,
      address: "123 Landlord Ave",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @house1 = House.create!(
      landlord: @landlord,
      name: "Sunrise Mansion",
      mode: :room,
      address_l1: "1 Alpha St",
      address_l2: "Ward A",
      address_l3: "District A",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor1 = @house1.floors.create!(name: "Tầng 1", position: 1)
    room1 = floor1.rooms.create!(name: "101", area: 20, max_slots: 2, tenants_count: 2)
    room1.create_rental_unit!(rent: 2_000_000, deposit: 2_000_000)

    @house2 = House.create!(
      landlord: @landlord,
      name: "Moonlight Villa",
      mode: :room,
      address_l1: "2 Beta St",
      address_l2: "Ward B",
      address_l3: "District B",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor2 = @house2.floors.create!(name: "Tầng 1", position: 1)
    room2 = floor2.rooms.create!(name: "201", area: 20, max_slots: 2, tenants_count: 0)
    room2.create_rental_unit!(rent: 2_000_000, deposit: 2_000_000)
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

  test "landlord can view houses index with state filter" do
    sign_in_as(@landlord_user)

    get landlord_houses_path
    assert_response :success
    assert_includes response.body, "Sunrise Mansion"
    assert_includes response.body, "Moonlight Villa"
    assert_select "select[name='state']"

    # Filter full
    get landlord_houses_path, params: { state: "full" }
    assert_response :success
    assert_includes response.body, "Sunrise Mansion"
    assert_not_includes response.body, "Moonlight Villa"

    # Filter empty
    get landlord_houses_path, params: { state: "empty" }
    assert_response :success
    assert_includes response.body, "Moonlight Villa"
    assert_not_includes response.body, "Sunrise Mansion"
  end

  test "renders no houses found when search or filter yields no results" do
    sign_in_as(@landlord_user)

    get landlord_houses_path, params: { query: "NON_EXISTING_HOUSE_NAME" }
    assert_response :success
    assert_includes response.body, I18n.t("form.house.no_houses_found")
  end

  test "show modal displays asset summary stats when assets exist" do
    sign_in_as(@landlord_user)

    room1 = @house1.rooms.first
    room1.assets.create!(
      category: "air_con",
      price: 5_000_000,
      status: :normal
    )
    room1.assets.create!(
      category: "fridge",
      price: 3_000_000,
      status: :damaged
    )

    get landlord_house_path(@house1)
    assert_response :success
    assert_includes response.body, I18n.t("form.asset.stats.total_assets")
    assert_includes response.body, "2 #{I18n.t('form.asset.stats.unit')}"
    assert_includes response.body, I18n.t("form.asset.stats.good_condition")
    assert_includes response.body, I18n.t("form.asset.stats.damaged_condition")
    assert_includes response.body, "8,000,000"
  end

  test "show modal displays none message when house has no assets" do
    sign_in_as(@landlord_user)

    get landlord_house_path(@house2)
    assert_response :success
    assert_includes response.body, I18n.t("form.asset.none")
  end

  test "landlord can change mode of empty house" do
    sign_in_as(@landlord_user)

    patch change_mode_landlord_house_path(@house2)

    assert_redirected_to edit_landlord_house_path(@house2)
    assert_equal I18n.t("success_messages.house_mode_changed"), flash[:notice]
    assert_predicate @house2.reload, :bed?
  end

  test "landlord cannot change mode of occupied house" do
    sign_in_as(@landlord_user)

    patch change_mode_landlord_house_path(@house1)

    assert_redirected_to edit_landlord_house_path(@house1)
    assert_equal I18n.t("form.house.change_mode_blocked"), flash[:alert]
    assert_predicate @house1.reload, :room?
  end

  test "landlord can delete empty house (soft delete)" do
    sign_in_as(@landlord_user)

    delete landlord_house_path(@house2)

    assert_redirected_to landlord_houses_path
    assert_equal I18n.t("success_messages.house_deleted"), flash[:notice]
    assert @house2.reload.is_deleted?
    assert @house2.rooms.count > 0
  end

  test "landlord cannot delete occupied house" do
    sign_in_as(@landlord_user)

    delete landlord_house_path(@house1)

    assert_redirected_to edit_landlord_house_path(@house1)
    assert_equal I18n.t("errors.house_cant_deleted"), flash[:alert]
    assert_not @house1.reload.is_deleted?
  end

  test "landlord can filter houses by invoice_status and see unpaid invoice badge" do
    sign_in_as(@landlord_user)

    floor1 = @house1.floors.first
    room1 = floor1.rooms.first
    @house1.invoices.create!(
      code: "HD-H1-01",
      title: "Tiền phòng",
      room: room1,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 2_000_000,
      total_amount: 2_000_000
    )

    floor2 = @house2.floors.first
    room2 = floor2.rooms.first
    @house2.invoices.create!(
      code: "HD-H2-01",
      title: "Tiền phòng cũ",
      room: room2,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :paid,
      paid_at: Time.current,
      payment_method: "cash",
      subtotal: 2_000_000,
      total_amount: 2_000_000
    )

    # 1. Default index displays both and shows badge on house1
    get landlord_houses_path
    assert_response :success
    assert_select "select[name='invoice_status']"
    assert_includes response.body, "Sunrise Mansion"
    assert_includes response.body, "Moonlight Villa"
    assert_includes response.body, I18n.t("form.house.unpaid_invoices_badge", count: 1)

    # 2. Filter has_unpaid shows only house1
    get landlord_houses_path, params: { invoice_status: "has_unpaid" }
    assert_response :success
    assert_includes response.body, "Sunrise Mansion"
    assert_not_includes response.body, "Moonlight Villa"

    # 3. Filter all_paid shows only house2
    get landlord_houses_path, params: { invoice_status: "all_paid" }
    assert_response :success
    assert_includes response.body, "Moonlight Villa"
    assert_not_includes response.body, "Sunrise Mansion"
  end
end
