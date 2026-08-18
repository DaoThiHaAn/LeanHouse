class PublicPagesController < ApplicationController
  def main_home
    # TODO: Render the main home page for the public except for admin
    render "public_pages/main_home"
  end


  def privacy
  end

  def terms
  end

  def report_issues
  end
end
