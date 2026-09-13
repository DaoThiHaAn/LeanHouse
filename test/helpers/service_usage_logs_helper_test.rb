# frozen_string_literal: true

require "test_helper"

class ServiceUsageLogsHelperTest < ActionView::TestCase
  setup do
    @confirmed_log = Struct.new(:is_confirmed?, :confirmed_at, :billed?).new(
      true,
      Time.zone.parse("2026-09-14 10:30:00"),
      false
    )

    @unconfirmed_log = Struct.new(:is_confirmed?, :confirmed_at, :billed?).new(
      false,
      nil,
      false
    )

    @billed_log = Struct.new(:is_confirmed?, :confirmed_at, :billed?).new(
      true,
      Time.zone.parse("2026-09-14 10:30:00"),
      true
    )
  end

  test "usage_log_confirmation_badge renders confirmed badge" do
    html = usage_log_confirmation_badge(@confirmed_log)
    assert_includes html, "bg-success-subtle"
    assert_includes html, "check_circle"
    assert_includes html, I18n.t("invoice.status_confirmed")
  end

  test "usage_log_confirmation_badge renders unconfirmed badge" do
    html = usage_log_confirmation_badge(@unconfirmed_log)
    assert_includes html, "bg-warning-subtle"
    assert_includes html, "schedule"
    assert_includes html, I18n.t("invoice.status_unconfirmed")
  end

  test "usage_log_billed_badge renders badge when billed" do
    html = usage_log_billed_badge(@billed_log)
    assert_includes html, "bg-info-subtle"
    assert_includes html, I18n.t("invoice.status_billed")
  end

  test "usage_log_billed_badge returns nil when not billed" do
    assert_nil usage_log_billed_badge(@confirmed_log)
  end

  test "usage_log_billed_badge renders unbilled text when show_unbilled is true" do
    html = usage_log_billed_badge(@confirmed_log, show_unbilled: true)
    assert_includes html, "fst-italic"
    assert_includes html, I18n.t("service_usage_logs.not_billed_yet")
  end

  test "usage_log_billed_badge includes extra_class when provided" do
    html = usage_log_billed_badge(@billed_log, extra_class: "custom-class")
    assert_includes html, "custom-class"
  end

  test "usage_log_confirmed_at renders formatted timestamp when confirmed with confirmed_at" do
    html = usage_log_confirmed_at(@confirmed_log)
    assert_includes html, I18n.l(@confirmed_log.confirmed_at, format: :default)
  end

  test "usage_log_confirmed_at returns nil when not confirmed" do
    assert_nil usage_log_confirmed_at(@unconfirmed_log)
  end

  test "usage_log_status_badges composites badges and timestamp" do
    html = usage_log_status_badges(@billed_log)
    assert_includes html, I18n.t("invoice.status_confirmed")
    assert_includes html, I18n.t("invoice.status_billed")
    assert_includes html, I18n.l(@billed_log.confirmed_at, format: :default)
  end

  test "fixed_tab? checks if tab is fixed" do
    assert fixed_tab?("fixed")
    assert_not fixed_tab?("real_time")
    assert_not fixed_tab?(nil)
  end

  test "real_time_tab? checks if tab is real_time or default" do
    assert real_time_tab?("real_time")
    assert real_time_tab?(nil)
    assert_not real_time_tab?("fixed")
  end

  test "usage_logs_tab_class returns active or inactive classes" do
    assert_equal "active shadow-sm", usage_logs_tab_class("fixed", "fixed")
    assert_equal "text-secondary", usage_logs_tab_class("real_time", "fixed")
    assert_equal "active shadow-sm", usage_logs_tab_class("real_time", nil)
    assert_equal "text-secondary", usage_logs_tab_class("fixed", nil)
  end

  test "house_usage_logs_tab_meta returns correct metadata for fixed tab" do
    meta = house_usage_logs_tab_meta("fixed")
    assert_equal "lock", meta[:icon]
    assert_equal I18n.t("service_usage_logs.house_tab_fixed"), meta[:page_title]
    assert_equal I18n.t("service_usage_logs.house_fixed_summary_title"), meta[:title]
    assert_equal I18n.t("service_usage_logs.house_fixed_summary_subtitle"), meta[:subtitle]
  end

  test "house_usage_logs_tab_meta returns correct metadata for real_time tab" do
    meta = house_usage_logs_tab_meta("real_time")
    assert_equal "electric_meter", meta[:icon]
    assert_equal I18n.t("service_usage_logs.house_tab_real_time"), meta[:page_title]
    assert_equal I18n.t("service_usage_logs.house_realtime_summary_title"), meta[:title]
    assert_equal I18n.t("service_usage_logs.house_realtime_summary_subtitle"), meta[:subtitle]
  end

  test "usage_logs_tab_icon returns correct icon" do
    assert_equal "lock", usage_logs_tab_icon("fixed")
    assert_equal "electric_meter", usage_logs_tab_icon("real_time")
  end
end
