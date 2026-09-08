require "test_helper"

class PublicPagesControllerTest < ActionDispatch::IntegrationTest
  test "GET /report-issues succeeds" do
    get report_issues_url
    assert_response :success
    assert_select "h1", text: I18n.t("incident_reports.title").upcase
    assert_select "form[action='#{create_issue_report_path}']"
    assert_select "input[name='issue_report[email]']"
    assert_select "input[name='issue_report[title]'][data-character-counter-target='input']"
    assert_select "textarea[name='issue_report[description]'][data-character-counter-target='input']"
    assert_select "[data-controller='character-counter']", count: 2
    assert_select "[data-character-counter-target='count']", count: 2
    assert_select "button[type='submit'][data-loading-target='button']"
    assert_select "span[data-loading-target='spinner']"
    assert_select "span[data-loading-target='icon']"
  end

  test "POST /report-issues with valid params creates issue report and redirects with flash notice" do
    assert_difference "IssueReport.count", 1 do
      post create_issue_report_url, params: {
        issue_report: {
          email: "user@example.com",
          title: "Cannot generate invoice PDF",
          description: "Clicking export invoice triggers a 500 error in room 101."
        }
      }
    end

    assert_redirected_to report_issues_url
    follow_redirect!
    assert_select ".alert", text: /#{I18n.t("incident_reports.created_success")}/

    created_report = IssueReport.last
    assert_equal "user@example.com", created_report.email
    assert_equal "Cannot generate invoice PDF", created_report.title
    assert_equal "pending", created_report.status
  end

  test "POST /report-issues with invalid params returns unprocessable_entity and shows errors" do
    assert_no_difference "IssueReport.count" do
      post create_issue_report_url, params: {
        issue_report: {
          email: "bad-email",
          title: "",
          description: "short"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert-danger"
  end
end
