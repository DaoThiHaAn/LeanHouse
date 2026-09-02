require "test_helper"

class LandlordPortal::AssetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Asset Master",
      tel: "0907778899",
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
      name: "Asset Controller House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)

    @asset_1 = @room.assets.create!(
      category: "air_con",
      price: 10_000_000,
      brand: "Daikin",
      model: "FTKQ25",
      purchased_at: 1.year.ago.to_date,
      status: :normal
    )
    @asset_2 = @room.assets.create!(
      category: "fridge",
      price: 15_000_000,
      brand: "Panasonic",
      model: "NR-BV360",
      purchased_at: 6.months.ago.to_date,
      status: :damaged
    )
  end

  test "landlord can view asset index page with 3 stats cards" do
    sign_in_as(@landlord_user)

    get landlord_house_assets_path(@house)
    assert_response :success
    assert_select "h1", text: I18n.t("page_titles.asset_mng")
    assert_select "div#asset_stats_grid" do
      # 3 stat cards
      assert_select "div.stat-card", 3
      # Check values
      assert_select "div.stat-card-teal", text: /2/ # total count
      assert_select "div.stat-card-blue", text: /25,000,000/ # total value
    end
  end

  test "filtered returns asset table partial" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_assets_path(@house, status: "damaged")
    assert_response :success
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@asset_2)}"
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@asset_1)}", count: 0
  end

  test "landlord can view new asset modal" do
    sign_in_as(@landlord_user)

    get new_landlord_house_asset_path(@house)
    assert_response :success
    assert_select "turbo-frame#new_asset_modal"
  end

  test "landlord creates asset successfully and updates stats upon reload" do
    sign_in_as(@landlord_user)

    assert_difference -> { @house.assets.count }, 1 do
      post landlord_house_assets_path(@house), params: {
        category_select: "tv",
        asset: {
          room_id: @room.id,
          price: 5_000_000,
          brand: "Sony",
          model: "Bravia",
          status: "normal"
        }
      }
    end

    assert_redirected_to landlord_house_assets_path(@house)
    follow_redirect!
    assert_equal I18n.t("success_messages.asset_created"), flash[:notice]
    assert_select "div#asset_stats_grid" do
      assert_select "div.stat-card-teal", text: /3/ # updated total count: 2 + 1 = 3
      assert_select "div.stat-card-blue", text: /30,000,000/ # updated total price: 25M + 5M = 30M
    end
  end

  test "landlord updates asset and turbo stream replaces stats cards" do
    sign_in_as(@landlord_user)

    # Change asset_1 (normal, 10M) to damaged and 12M
    patch landlord_house_asset_path(@house, @asset_1), params: {
      asset: {
        status: "damaged",
        price: 12_000_000
      }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "action=\"replace\" target=\"#{ActionView::RecordIdentifier.dom_id(@asset_1)}\""
    assert_includes response.body, "action=\"replace\" target=\"asset_stats_grid\""
    assert_includes response.body, "close-modal"

    @asset_1.reload
    assert_equal "damaged", @asset_1.status
    assert_equal 12_000_000, @asset_1.price

    # Stats: total 2, normal 0, damaged 2, total_price 12M + 15M = 27M
    assert_includes response.body, "27,000,000"
  end

  test "landlord destroys asset and turbo stream removes row and replaces stats cards" do
    sign_in_as(@landlord_user)

    assert_difference -> { @house.assets.count }, -1 do
      delete landlord_house_asset_path(@house, @asset_2), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "action=\"remove\" target=\"#{ActionView::RecordIdentifier.dom_id(@asset_2)}\""
    assert_includes response.body, "action=\"replace\" target=\"asset_stats_grid\""

    # Remaining: asset_1 (normal, 10M) -> total 1, total_price 10M
    assert_includes response.body, "10,000,000"
  end

  private

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end
end
