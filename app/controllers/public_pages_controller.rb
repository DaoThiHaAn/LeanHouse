class PublicPagesController < ApplicationController
  def main_home
    if !logged_in?
      render "public_pages/main_home"
    elsif current_user.role == "landlord"
      redirect_to landlord_dashboard_index_path(landlord_id: current_user.id)
    elsif current_user.role == "tenant"
      redirect_to tenant_dashboard_index_path(tenant_id: current_user.id)
    else
      redirect_to admin_dashboard_index_path(admin_id: current_user.id)
    end
  end

  def about
  end

  def features
    render "public_pages/main_home"
  end

  def contact
  end

  def privacy
  end

  def terms
  end

  def report_issues
  end
end
