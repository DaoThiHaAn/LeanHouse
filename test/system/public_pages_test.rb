# frozen_string_literal: true

require "application_system_test_case"

class PublicPagesTest < ApplicationSystemTestCase
  test "visitor can navigate public pages (home, privacy, terms)" do
    visit root_path
    assert_selector "a[href='#{login_path}']", wait: 5

    visit privacy_path
    assert_current_path privacy_path

    visit terms_of_use_path
    assert_current_path terms_of_use_path
  end

  test "visitor can submit an issue report from the public report-issues page" do
    visit report_issues_path

    assert_selector "form[action='#{create_issue_report_path}']", wait: 5
    fill_in "issue_report[email]", with: "reporter@leanhouse.vn"
    fill_in "issue_report[title]", with: "Không nhận được mã OTP khi đăng ký"
    fill_in "issue_report[description]", with: "Tôi đã nhập số điện thoại hợp lệ nhưng hệ thống báo lỗi gửi mã."

    assert_difference -> { IssueReport.count }, 1 do
      find("button[type='submit'], input[type='submit']").click
      assert_current_path report_issues_path, wait: 5
    end

    assert_equal "reporter@leanhouse.vn", IssueReport.last.email
  end
end
