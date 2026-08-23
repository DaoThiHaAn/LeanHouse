class NotificationsController < ApplicationController
  before_action :authenticate_user!

  # Đánh dấu 1 thông báo cụ thể là đã đọc
  def mark_as_read
    notification = current_user.notifications.find(params[:id])
    notification.update!(read_at: Time.current)

    render_dropdown_stream
  end

  # Mark all unread ones as read
  def mark_all_as_read
    current_user.notifications.where(read_at: nil).update_all(
      read_at: Time.current,
      updated_at: Time.current
    )

    render_dropdown_stream
  end

  private

  def render_dropdown_stream
    @notifications = current_user.notifications.order(created_at: :desc).limit(10)
    @unread_count = current_user.notifications.unread.count
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "notification_box",
          partial: "layouts/shared_components/notification_dropdown",
          locals: {
            unread_count: @unread_count,
            notifications: @notifications
          }
        )
      end
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
