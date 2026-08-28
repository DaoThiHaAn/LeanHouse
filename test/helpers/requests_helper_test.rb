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

  test "request_status_badge returns styled badge tag" do
    badge = request_status_badge(:pending)
    assert_includes badge, "bg-warning"
    assert_includes badge, I18n.t("enums.request.status.pending")
  end
end
