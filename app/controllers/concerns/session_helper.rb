module SessionHelper
  REMEMBER_DURATION = 14.days

  def log_in(user, remember_me: false)
    # Store user information in the session
    session[:user_id] = user.id
    session[:role] = user.role

    if remember_me
      remember_user(user)
    else
      forget_user
    end

    Rails.logger.debug "SESSION: #{session.to_hash}"
  end

  def remember_user(user)
    return unless user.respond_to?(:password_digest) && user.password_digest.present?

    cookies.signed[:remember_user] = {
      value: [ user.id, user.password_digest.slice(0, 16) ],
      expires: REMEMBER_DURATION,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def forget_user
    cookies.delete(:remember_user)
  end

  def current_user
    if session[:user_id]
      @current_user ||= User.kept.with_attached_avatar.find_by(id: session[:user_id], is_active: true)
    elsif cookies.signed[:remember_user].present?
      user_id, digest_salt = cookies.signed[:remember_user]
      user = User.kept.with_attached_avatar.find_by(id: user_id, is_active: true)

      if user && digest_salt.present? && user.password_digest&.start_with?(digest_salt)
        session[:user_id] = user.id
        session[:role] = user.role
        @current_user = user
      else
        forget_user
        @current_user = nil
      end
    end
  end

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id], is_active: true) if session[:admin_id]
  end

  def logged_in?
    current_user.present?
  end

  def admin_logged_in?
    current_admin.present?
  end

  def destroy_session
    forget_user
    reset_session
    @current_user = nil
  end

  def clear_session_keys(*keys)
    keys.each { |key| session.delete(key) }
  end
end
