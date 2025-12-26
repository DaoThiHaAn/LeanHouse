module SessionHelper
  def log_in(user)
    session[:user_id] = user.id
    session[:role] = user.role

    Rails.logger.debug "SESSION: #{session.to_hash}"
  end

  def current_user
    @current_user ||= User.kept.with_attached_avatar.find_by(id: session[:user_id], is_active: true)
  end

  def logged_in?
    current_user.present?
  end

  def destroy_session
    reset_session
  end

  def clear_session_keys(*keys)
    keys.each { |key| session.delete(key) }
  end
end
