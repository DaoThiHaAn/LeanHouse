require "test_helper"

class AdminPortal::IssueReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(
      email: "superadmin_issues@leanhouse.vn",
      fullname: "Super Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @report_pending = IssueReport.create!(
      email: "user1@example.com",
      title: "Broken payment gateway",
      description: "VietQR is not scanning properly on mobile safari.",
      status: :pending
    )

    @report_resolved = IssueReport.create!(
      email: "user2@example.com",
      title: "Cannot reset password",
      description: "Did not receive OTP via SMS yesterday.",
      status: :resolved,
      resolved_by: @admin,
      resolved_at: 1.day.ago,
      admin_notes: "Checked SMS logs and assisted user directly."
    )
  end

  def sign_in_admin(admin = @admin)
    post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
  end

  test "should redirect to admin login when unauthenticated" do
    get admin_issue_reports_url
    assert_redirected_to admin_login_url

    get admin_issue_report_url(@report_pending)
    assert_redirected_to admin_login_url
  end

  test "should get index and display KPI counts when authenticated" do
    sign_in_admin

    get admin_issue_reports_url
    assert_response :success
    assert_select "h1", text: I18n.t("admin.issue_reports.title")

    assert_includes response.body, "Broken payment gateway"
    assert_includes response.body, "Cannot reset password"
    assert_includes response.body, "user1@example.com"
    assert_select ".admin-nav-badge", text: "1"
  end

  test "should filter issue reports by status" do
    sign_in_admin

    get admin_issue_reports_url, params: { status: "pending" }
    assert_response :success
    assert_includes response.body, "Broken payment gateway"
    assert_not_includes response.body, "Cannot reset password"
  end

  test "should filter issue reports by search query" do
    sign_in_admin

    get admin_issue_reports_url, params: { q: "payment" }
    assert_response :success
    assert_includes response.body, "Broken payment gateway"
    assert_not_includes response.body, "Cannot reset password"
  end

  test "should show issue report details" do
    sign_in_admin

    get admin_issue_report_url(@report_pending)
    assert_response :success
    assert_includes response.body, "Broken payment gateway"
    assert_includes response.body, "VietQR is not scanning properly"
    assert_includes response.body, "user1@example.com"
    assert_select "form.issue-report-edit-form[data-controller='loading']"
    assert_select "button[type='submit'][data-loading-target='button']"
    assert_select "span[data-loading-target='spinner']"
    assert_select "span[data-loading-target='icon']"
  end

  test "should update issue report status to in_progress" do
    sign_in_admin

    patch admin_issue_report_url(@report_pending), params: {
      issue_report: {
        status: "in_progress",
        admin_notes: "Investigating with technical team"
      }
    }

    assert_redirected_to admin_issue_report_url(@report_pending)
    @report_pending.reload
    assert_equal "in_progress", @report_pending.status
    assert_equal "Investigating with technical team", @report_pending.admin_notes
  end

  test "should update issue report status to resolved and assign admin" do
    sign_in_admin

    patch admin_issue_report_url(@report_pending), params: {
      issue_report: {
        status: "resolved",
        admin_notes: "Fixed VietQR canvas scaling bug"
      }
    }

    assert_redirected_to admin_issue_report_url(@report_pending)
    @report_pending.reload
    assert_equal "resolved", @report_pending.status
    assert_equal @admin, @report_pending.resolved_by
    assert_not_nil @report_pending.resolved_at
    assert_equal "Fixed VietQR canvas scaling bug", @report_pending.admin_notes
  end

  test "report row contains links with data-turbo-frame _top" do
    sign_in_admin

    get admin_issue_reports_url
    assert_response :success
    assert_select "a[data-turbo-frame='_top'][href=?]", admin_issue_report_path(@report_pending)
  end
end
