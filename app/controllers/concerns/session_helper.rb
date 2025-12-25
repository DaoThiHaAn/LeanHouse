module SessionHelper
  def log_in(user)
    session[:user_id] = user.id
    session[:role] = user.role

    Rails.logger.debug "SESSION: #{session.to_hash}"
  end

  def current_user
    @current_user ||= User.kept.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def log_out
    session.delete(:user_id)
    session[:role] = "guest"
  end
end
