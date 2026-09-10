require "test_helper"

class NotificationsHelperTest < ActionView::TestCase
  test "notification_level_badge renders appropriate badges for levels" do
    urgent_badge = notification_level_badge("urgent")
    assert_includes urgent_badge, "bg-danger-subtle"
    assert_includes urgent_badge, "error"
    assert_includes urgent_badge, I18n.t("admin.notifications.levels.urgent")

    warning_badge = notification_level_badge("warning")
    assert_includes warning_badge, "bg-warning-subtle"
    assert_includes warning_badge, "warning"
    assert_includes warning_badge, I18n.t("admin.notifications.levels.warning")

    info_badge = notification_level_badge("info")
    assert_includes info_badge, "bg-info-subtle"
    assert_includes info_badge, "info"
    assert_includes info_badge, I18n.t("admin.notifications.levels.info")

    default_badge = notification_level_badge("unknown")
    assert_includes default_badge, "bg-info-subtle"
  end

  test "notification_audience_badge renders appropriate badges for audiences" do
    landlords_badge = notification_audience_badge("landlords")
    assert_includes landlords_badge, "bg-primary-subtle"
    assert_includes landlords_badge, I18n.t("admin.notifications.audience.landlords")

    tenants_badge = notification_audience_badge("tenants")
    assert_includes tenants_badge, "bg-success-subtle"
    assert_includes tenants_badge, I18n.t("admin.notifications.audience.tenants")

    all_badge = notification_audience_badge("all")
    assert_includes all_badge, "bg-secondary-subtle"
    assert_includes all_badge, I18n.t("admin.notifications.audience.all")

    default_badge = notification_audience_badge("unknown")
    assert_includes default_badge, "bg-secondary-subtle"
  end
end
