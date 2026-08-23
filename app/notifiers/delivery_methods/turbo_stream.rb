class DeliveryMethods::TurboStream < Noticed::DeliveryMethod
  def deliver
    user = recipient
    return unless user.is_a?(User)

    unread_count = user.notifications.unread.count
    notifications = user.notifications.order(created_at: :desc).limit(10)

    # Bắn Turbo Stream qua WebSocket tới đúng user nhận
    Turbo::StreamsChannel.broadcast_update_to(
      [ user, :notifications ],
      target: "notification_box",
      partial: "layouts/shared_components/notification_dropdown",
      locals: {
        unread_count: unread_count,
        notifications: notifications
      }
    )
  end
end
