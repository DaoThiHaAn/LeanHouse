module AdminPortal
  class IssueReportsController < BaseController
    before_action :set_issue_report, only: [ :show, :update ]

    def index
      @query = params[:q].presence
      @status = params[:status].presence
      @from_date = params[:from_date].presence
      @to_date = params[:to_date].presence

      base_scope = IssueReport.includes(:resolved_by).recent
      base_scope = base_scope.filter_by_date_range(@from_date, @to_date)
      base_scope = base_scope.search(@query)

      @pending_count = base_scope.pending.count
      @in_progress_count = base_scope.in_progress.count

      scope = @status.present? ? base_scope.filter_by_status(@status) : base_scope
      @issue_reports = scope.page(params[:page]).per(15)
    end

    def show
    end

    def update
      new_status = params.dig(:issue_report, :status)
      admin_notes = params.dig(:issue_report, :admin_notes)

      if new_status == "resolved"
        @issue_report.mark_resolved!(admin: current_admin, notes: admin_notes)
      elsif new_status == "in_progress"
        @issue_report.mark_in_progress!(notes: admin_notes)
      elsif new_status == "pending"
        @issue_report.update!(
          status: :pending,
          admin_notes: admin_notes,
          resolved_by: nil,
          resolved_at: nil
        )
      else
        @issue_report.update!(admin_notes: admin_notes)
      end

      redirect_to admin_issue_report_path(@issue_report), notice: t("admin.issue_reports.update_success")
    end

    private

    def set_issue_report
      @issue_report = IssueReport.includes(:resolved_by).find(params[:id])
    end
  end
end
