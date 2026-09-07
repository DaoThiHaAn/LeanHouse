require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "back_link_to with default arguments generates back link with default text and icon" do
    result = back_link_to

    assert_includes result, 'class="turn-back link"'
    assert_includes result, '<span class="material-symbols-outlined turn-back-icon">arrow_back</span>'
    assert_includes result, '<span class="turn-back-text">'
    assert_includes result, I18n.t("turn_back")
  end

  test "back_link_to with custom path" do
    result = back_link_to("/houses")

    assert_includes result, 'href="/houses"'
    assert_includes result, 'class="turn-back link"'
    assert_includes result, I18n.t("turn_back")
  end

  test "back_link_to with custom path and custom text" do
    result = back_link_to("/houses", "Back to house list")

    assert_includes result, 'href="/houses"'
    assert_includes result, "Back to house list"
  end

  test "back_link_to with custom path and symbol text" do
    result = back_link_to("/houses", :turn_back)

    assert_includes result, 'href="/houses"'
    assert_includes result, I18n.t("turn_back")
  end

  test "back_link_to with custom icon and extra classes" do
    result = back_link_to("/houses", icon: "arrow_left_alt", class: "align-self-start custom-class")

    assert_includes result, 'class="turn-back link align-self-start custom-class"'
    assert_includes result, '<span class="material-symbols-outlined turn-back-icon">arrow_left_alt</span>'
  end

  test "back_link_to with options hash as first argument" do
    result = back_link_to(class: "mx-auto mt-3")

    assert_includes result, 'class="turn-back link mx-auto mt-3"'
    assert_includes result, I18n.t("turn_back")
  end

  test "back_link_to with block" do
    result = back_link_to("/houses", class: "custom-block") do
      tag.span("Custom Content", class: "custom-text")
    end

    assert_includes result, 'href="/houses"'
    assert_includes result, 'class="turn-back link custom-block"'
    assert_includes result, '<span class="custom-text">Custom Content</span>'
  end

  test "turn_back_link is an alias for back_link_to" do
    result = turn_back_link("/profile")

    assert_includes result, 'href="/profile"'
    assert_includes result, 'class="turn-back link"'
    assert_includes result, I18n.t("turn_back")
  end

  test "format_money formats integers as Vietnamese Dong" do
    assert_equal "50,000 đ", format_money(50000)
    assert_equal "1,500,000 đ", format_money(1500000)
    assert_equal "0 đ", format_money(0)
  end

  test "format_date formats dates as dd/mm/yyyy" do
    date = Date.new(2026, 9, 8)
    assert_equal "08/09/2026", format_date(date)
    assert_equal "-", format_date(nil)
    assert_equal "N/A", format_date(nil, fallback: "N/A")
  end

  test "format_datetime formats timestamps as HH:MM dd/mm/yyyy" do
    time = Time.zone.local(2026, 9, 8, 14, 30, 45)
    assert_equal "14:30 08/09/2026", format_datetime(time)
    assert_equal "14:30:45 08/09/2026", format_datetime(time, include_seconds: true)
    assert_equal "-", format_datetime(nil)
    assert_equal "Chưa cập nhật", format_datetime(nil, fallback: "Chưa cập nhật")
  end

  test "format_time and format_timestamp are aliases for format_datetime" do
    time = Time.zone.local(2026, 9, 8, 9, 15, 0)
    assert_equal "09:15 08/09/2026", format_time(time)
    assert_equal "09:15 08/09/2026", format_timestamp(time)
  end

  test "format_month formats date or time as mm/yyyy" do
    date = Date.new(2026, 9, 1)
    assert_equal "09/2026", format_month(date)
    assert_equal "-", format_month(nil)
  end
end
