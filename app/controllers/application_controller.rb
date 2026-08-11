class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include SessionHelper
  helper_method :current_user, :logged_in?

  # Set locale from params or default locale
  around_action :switch_locale

  # Retreive notifications of current user
  before_action :set_notifications

  def switch_locale(&action)
    locale = params[:lang] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  # Cancancan rescue for unauthorized access
  rescue_from CanCan::AccessDenied do |_exception|
    @back_url = request.referrer || root_path
    respond_to do |format|
      format.html do
        render template: "errors/unauthorized",
               status: :forbidden,
               layout: "application" # Use system layout
      end

      format.json { head :forbidden }
    end
  end

  private

  def authenticate_user!
    return if logged_in?

    redirect_to login_path, alert: t("errors.login_required")
  end

  def set_notifications
    return unless current_user

    @notifications = current_user.notifications
                                  .order(created_at: :desc)
                                  .limit(10)

    @unread_count = current_user.notifications.unread.count
  end
end
