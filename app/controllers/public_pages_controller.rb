class PublicPagesController < ApplicationController
  def main_home
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
