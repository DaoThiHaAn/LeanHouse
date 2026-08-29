class NotificationsController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :authenticate_user!

  def index
    @filter = params[:filter].presence_in(%w[all unread read]) || "all"

    scope = current_user.notifications.order(created_at: :desc)
    scope = scope.unread if @filter == "unread"
    scope = scope.read if @filter == "read"

    @notifications_list = scope.page(params[:page]).per(20)
  end

  # Đánh dấu 1 thông báo cụ thể là đã đọc
  def mark_as_read
    @notification = current_user.notifications.find(params[:id])
    @notification.update!(read_at: Time.current)

    @notifications = current_user.notifications.order(created_at: :desc).limit(10)
    @unread_count = current_user.notifications.unread.count

    respond_to do |format|
      format.turbo_stream do
        streams = [
          turbo_stream.update(
            "notification_box",
            partial: "layouts/shared_components/notification_dropdown",
            locals: {
              unread_count: @unread_count,
              notifications: @notifications
            }
          ),
          turbo_stream.replace(
            dom_id(@notification),
            partial: "notifications/notification",
            locals: { notification: @notification }
          ),
          turbo_stream.update(
            "unread_filter_badge",
            partial: "notifications/unread_badge",
            locals: { unread_count: @unread_count }
          )
        ]
        streams << turbo_stream.update("mark_all_read_btn_container", "") if @unread_count.zero?
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: root_path }
    end
  end

  # Mark all unread ones as read
  def mark_all_as_read
    current_user.notifications.where(read_at: nil).update_all(
      read_at: Time.current,
      updated_at: Time.current
    )

    @notifications = current_user.notifications.order(created_at: :desc).limit(10)
    @unread_count = 0

    @filter = params[:filter].presence_in(%w[all unread read]) || "all"
    scope = current_user.notifications.order(created_at: :desc)
    scope = scope.unread if @filter == "unread"
    scope = scope.read if @filter == "read"
    @notifications_list = scope.page(params[:page]).per(20)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update(
            "notification_box",
            partial: "layouts/shared_components/notification_dropdown",
            locals: {
              unread_count: @unread_count,
              notifications: @notifications
            }
          ),
          turbo_stream.update(
            "notifications_page_content",
            partial: "notifications/page_content",
            locals: {
              filter: @filter,
              notifications_list: @notifications_list,
              unread_count: @unread_count
            }
          )
        ]
      end
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
