module IssueReportsHelper
  def issue_report_status_badge(status)
    status_str = status.to_s

    icon_name, badge_class, label_key =
      case status_str
      when "pending"
        [ "hourglass_top", "issue-report-badge-pending", "admin.issue_reports.status_pending" ]
      when "in_progress"
        [ "sync", "issue-report-badge-in_progress", "admin.issue_reports.status_in_progress" ]
      when "resolved"
        [ "check_circle", "issue-report-badge-resolved", "admin.issue_reports.status_resolved" ]
      else
        [ "help", "bg-secondary-subtle text-secondary-emphasis", "admin.issue_reports.status_pending" ]
      end

    content_tag(:span, class: "issue-report-badge #{badge_class}") do
      concat content_tag(:span, icon_name, class: "material-symbols-filled fs-6", aria: { hidden: true })
      concat content_tag(:span, t(label_key, default: status_str.humanize))
    end
  end
end
