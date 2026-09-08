require "test_helper"
require "minitest/mock"

class IssueReportTest < ActiveSupport::TestCase
  setup do
    @admin = Admin.create!(
      email: "admin_tester@leanhouse.vn",
      fullname: "Admin Test",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @valid_attributes = {
      email: "user@example.com",
      title: "Cannot upload contract file",
      description: "Getting a 500 error every time I try to attach a PDF.",
      status: "pending"
    }
  end

  test "is valid with valid attributes" do
    report = IssueReport.new(@valid_attributes)
    assert report.valid?
  end

  test "requires valid email" do
    report = IssueReport.new(@valid_attributes.merge(email: ""))
    assert_not report.valid?
    assert report.errors[:email].any?

    report.email = "invalid-email"
    assert_not report.valid?
    assert report.errors[:email].any?
  end

  test "requires title presence and maximum 100 characters" do
    report = IssueReport.new(@valid_attributes.merge(title: "a" * 101))
    assert_not report.valid?

    report.title = ""
    assert_not report.valid?
  end

  test "requires description of minimum 10 characters" do
    report = IssueReport.new(@valid_attributes.merge(description: "Short"))
    assert_not report.valid?
  end

  test "defaults status to pending" do
    report = IssueReport.create!(@valid_attributes.except(:status))
    assert_equal "pending", report.status
    assert report.pending?
  end

  test "mark_resolved! updates status, resolved_by, and resolved_at" do
    report = IssueReport.create!(@valid_attributes)
    assert_nil report.resolved_at
    assert_nil report.resolved_by

    report.mark_resolved!(admin: @admin, notes: "Fixed in production")
    assert report.resolved?
    assert_equal @admin, report.resolved_by
    assert_not_nil report.resolved_at
    assert_equal "Fixed in production", report.admin_notes
  end

  test "mark_in_progress! updates status and notes" do
    report = IssueReport.create!(@valid_attributes)
    report.mark_in_progress!(notes: "Investigating server logs")
    assert report.in_progress?
    assert_equal "Investigating server logs", report.admin_notes
  end

  test "search scope filters by title and email" do
    r1 = IssueReport.create!(@valid_attributes.merge(email: "john@doe.com", title: "Login bug"))
    r2 = IssueReport.create!(@valid_attributes.merge(email: "jane@doe.com", title: "Payment failure"))

    results = IssueReport.search("john")
    assert_includes results, r1
    assert_not_includes results, r2

    results = IssueReport.search("Payment")
    assert_includes results, r2
    assert_not_includes results, r1
  end

  test "broadcast_pending_badge_later calls broadcast_pending_badge" do
    called = false
    IssueReport.stub :broadcast_pending_badge, -> { called = true } do
      report = IssueReport.new(@valid_attributes)
      report.send(:broadcast_pending_badge_later)
      assert called
    end
  end

  test "broadcast_pending_badge replaces admin_issue_reports_nav_badge on Turbo::StreamsChannel" do
    broadcasted = false
    Turbo::StreamsChannel.stub :broadcast_replace_to, ->(stream, options) {
      broadcasted = true
      assert_equal :admin_issue_reports, stream
      assert_equal "admin_issue_reports_nav_badge", options[:target]
    } do
      IssueReport.broadcast_pending_badge
      assert broadcasted
    end
  end
end
