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
end
