require "test_helper"

class LandlordPortal::MaintenanceLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
      tel: "0901112233",
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

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
    @asset = @room.assets.create!(
      category: "air_con",
      price: 5_000_000,
      brand: "Daikin",
      model: "FTKQ25",
      purchased_at: 1.year.ago.to_date,
      status: :normal
    )

    @log = @asset.maintenance_logs.create!(
      performed_on: Date.new(2025, 6, 5),
      cost: 100_000,
      content: "Bơm gas"
    )
  end

  test "landlord can view maintenance log index page" do
    sign_in_as(@landlord_user)

    get landlord_house_asset_maintenance_logs_path(@house, @asset)
    assert_response :success
    assert_select "h1", text: I18n.t("page_titles.maintenance_log_mng")
    assert_select "turbo-frame#log_table"
  end

  test "filtered returns log table partial with matching records" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_asset_maintenance_logs_path(@house, @asset, month: 6, year: 2025)
    assert_response :success
    assert_select "tr##{ActionView::RecordIdentifier.dom_id(@log)}"
    assert_includes response.body, "Bơm gas"
    assert_includes response.body, "100.000"
    assert_includes response.body, "5/6/2025"
  end

  test "filtered returns empty message when no records match filter" do
    sign_in_as(@landlord_user)

    get filtered_landlord_house_asset_maintenance_logs_path(@house, @asset, month: 1, year: 2024)
    assert_response :success
    assert_includes response.body, I18n.t("form.maintenance_log.unfound")
  end

  test "landlord can view new maintenance log modal" do
    sign_in_as(@landlord_user)

    get new_landlord_house_asset_maintenance_log_path(@house, @asset)
    assert_response :success
    assert_select "turbo-frame#new_log_modal"
  end

  test "landlord creates maintenance log successfully" do
    sign_in_as(@landlord_user)

    assert_difference -> { @asset.maintenance_logs.count }, 1 do
      post landlord_house_asset_maintenance_logs_path(@house, @asset), params: {
        maintenance_log: {
          performed_on: Date.new(2025, 4, 4),
          cost: 100_000,
          content: "Sửa ngăn lạnh bị đóng tuyết"
        }
      }
    end

    assert_redirected_to landlord_house_asset_maintenance_logs_path(@house, @asset)
    follow_redirect!
    assert_equal I18n.t("success_messages.maintenance_log_created"), flash[:notice]
  end

  test "create fails with invalid attributes" do
    sign_in_as(@landlord_user)

    assert_no_difference -> { @asset.maintenance_logs.count } do
      post landlord_house_asset_maintenance_logs_path(@house, @asset), params: {
        maintenance_log: {
          performed_on: nil,
          cost: -100,
          content: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "landlord can view edit maintenance log modal" do
    sign_in_as(@landlord_user)

    get edit_landlord_house_asset_maintenance_log_path(@house, @asset, @log)
    assert_response :success
    assert_select "turbo-frame#edit_log_modal"
  end

  test "landlord updates maintenance log successfully via turbo stream" do
    sign_in_as(@landlord_user)

    patch landlord_house_asset_maintenance_log_path(@house, @asset, @log), params: {
      maintenance_log: {
        content: "Bơm gas và vệ sinh",
        cost: 150_000,
        performed_on: @log.performed_on
      }
    }, as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "Bơm gas và vệ sinh"
    assert_includes response.body, "close-modal"

    @log.reload
    assert_equal "Bơm gas và vệ sinh", @log.content
    assert_equal 150_000, @log.cost
  end

  test "landlord hard deletes maintenance log successfully" do
    sign_in_as(@landlord_user)

    assert_difference -> { @asset.maintenance_logs.count }, -1 do
      delete landlord_house_asset_maintenance_log_path(@house, @asset, @log), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "action=\"remove\" target=\"#{ActionView::RecordIdentifier.dom_id(@log)}\""
    assert_not MaintenanceLog.exists?(@log.id)
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
