require "test_helper"

class ServicesHelperTest < ActionView::TestCase
  test "service_calculation_type_badge for metered (real_time) service variant" do
    variant = Struct.new(:is_real_time?).new(true)
    badge = service_calculation_type_badge(variant)

    assert_includes badge, "bg-info-subtle"
    assert_includes badge, "speed"
    assert_includes badge, I18n.t("admin.services.metered")
  end

  test "service_calculation_type_badge for fixed service variant" do
    variant = Struct.new(:is_real_time?).new(false)
    badge = service_calculation_type_badge(variant)

    assert_includes badge, "bg-secondary-subtle"
    assert_includes badge, "lock"
    assert_includes badge, I18n.t("admin.services.fixed")
  end

  test "service_variant_type_badge alias works identically" do
    variant = Struct.new(:is_real_time?).new(true)
    assert_equal service_calculation_type_badge(variant), service_variant_type_badge(variant)
  end
end
