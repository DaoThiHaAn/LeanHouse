require "test_helper"

class LandlordPortal::AssetsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get landlord_portal_assets_index_url
    assert_response :success
  end

  test "should get show" do
    get landlord_portal_assets_show_url
    assert_response :success
  end

  test "should get new" do
    get landlord_portal_assets_new_url
    assert_response :success
  end

  test "should get edit" do
    get landlord_portal_assets_edit_url
    assert_response :success
  end

  test "should get create" do
    get landlord_portal_assets_create_url
    assert_response :success
  end

  test "should get update" do
    get landlord_portal_assets_update_url
    assert_response :success
  end

  test "should get destroy" do
    get landlord_portal_assets_destroy_url
    assert_response :success
  end
end
