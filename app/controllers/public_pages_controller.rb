class PublicPagesController < ApplicationController
  def main_home
    render "public_pages/main_home"
  end


  def privacy
  end

  def terms
  end

  def report_issues
    @issue_report = IssueReport.new(email: current_admin&.email)
  end

  def create_issue_report
    @issue_report = IssueReport.new(issue_report_params)

    if @issue_report.save
      redirect_to report_issues_path, notice: t("incident_reports.created_success")
    else
      render :report_issues, status: :unprocessable_entity
    end
  end

  private

  def issue_report_params
    params.require(:issue_report).permit(:email, :title, :description)
  end
end
