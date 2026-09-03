require "test_helper"

class AssetsHelperTest < ActionView::TestCase
  include ApplicationHelper
  test "asset_status_badge for normal status" do
    badge = asset_status_badge("normal")
    assert_includes badge, "bg-success-subtle"
    assert_includes badge, "check_circle"
    assert_includes badge, I18n.t("enums.asset.status.normal")
  end

  test "asset_status_badge for damaged status" do
    badge = asset_status_badge("damaged")
    assert_includes badge, "bg-danger-subtle"
    assert_includes badge, "error"
    assert_includes badge, I18n.t("enums.asset.status.damaged")
  end

  test "asset_status_badge for under_repair status" do
    badge = asset_status_badge("under_repair")
    assert_includes badge, "bg-warning-subtle"
    assert_includes badge, "build"
    assert_includes badge, I18n.t("enums.asset.status.under_repair")
  end

  test "asset_status_badge when passed an Asset object" do
    asset = Struct.new(:status).new("normal")
    badge = asset_status_badge(asset)
    assert_includes badge, "bg-success-subtle"
    assert_includes badge, "check_circle"
  end

  test "asset_maintenance_cost_badge formats cost into badge" do
    badge = asset_maintenance_cost_badge(350_000)
    assert_includes badge, "badge"
    assert_includes badge, "bg-primary-subtle"
    assert_includes badge, "350,000"
  end

  test "asset_maintenance_cost_badge sums enumerable of logs" do
    log1 = Struct.new(:cost).new(100_000)
    log2 = Struct.new(:cost).new(250_000)
    badge = asset_maintenance_cost_badge([ log1, log2 ])
    assert_includes badge, "350,000"
  end
end
