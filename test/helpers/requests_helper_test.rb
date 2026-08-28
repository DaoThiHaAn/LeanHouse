require "test_helper"

class RequestsHelperTest < ActionView::TestCase
  setup do
    @tenant_user = User.create!(
      fullname: "Tenant Le",
      tel: "0907654321",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Tenant Rd",
      tel_verified_at: Time.current,
      created_at: 2.years.ago
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)
  end

  test "tenant_year_filter_options limits back to account creation year" do
    options = tenant_year_filter_options(@tenant)
    current_year = Date.current.year
    creation_year = 2.years.ago.year

    expected_years = [ [ I18n.t("all"), "" ] ] + current_year.downto(creation_year).map { |y| [ y.to_s, y.to_s ] }

    assert_equal expected_years, options
  end

  test "request_status_badge returns styled badge tag with default sm and optional lg size" do
    badge_sm = request_status_badge(:pending)
    assert_includes badge_sm, "request-status-badge"
    assert_includes badge_sm, "badge-pending"
    assert_includes badge_sm, "badge-sm"
    assert_includes badge_sm, I18n.t("enums.request.status.pending")

    badge_lg = request_status_badge(:approved, size: :lg)
    assert_includes badge_lg, "request-status-badge"
    assert_includes badge_lg, "badge-approved"
    assert_includes badge_lg, "badge-lg"
    assert_includes badge_lg, I18n.t("enums.request.status.approved")
  end
end
