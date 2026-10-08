class DeliveryMethods::TurboStream < Noticed::DeliveryMethod
  def deliver
    user = recipient
    return unless user.is_a?(User)

    unread_count = user.notifications.unread.count
    notifications = user.notifications.includes(:event).order(created_at: :desc).limit(10)

    # 1. Update dropdown & bell icon in navbar (with ringing animation)
    box_html = ApplicationController.render(
      partial: "layouts/shared_components/notification_dropdown",
      locals: {
        unread_count: unread_count,
        notifications: notifications,
        animate_bell: true
      }
    )

    streams = [
      Turbo::StreamsChannel.turbo_stream_action_tag(:update, target: "notification_box", template: box_html)
    ]

    # 2. If this delivery has an associated notification record, broadcast to Notification Center & Toast
    if notification.present?
      list_item_html = ApplicationController.render(
        partial: "notifications/notification",
        locals: { notification: notification }
      )
      badge_html = ApplicationController.render(
        partial: "notifications/unread_badge",
        locals: { unread_count: unread_count }
      )
      toast_html = ApplicationController.render(
        partial: "layouts/shared_components/notification_toast",
        locals: { notification: notification }
      )

      # Prepend to Notification Center list (if user is on /notifications)
      streams << Turbo::StreamsChannel.turbo_stream_action_tag(:prepend, target: "notifications_list_items", template: list_item_html)
      # Remove empty state card if present
      streams << Turbo::StreamsChannel.turbo_stream_action_tag(:remove, target: "notifications_empty_state")
      # Update unread badge on "Chưa đọc" filter tab
      streams << Turbo::StreamsChannel.turbo_stream_action_tag(:update, target: "unread_filter_badge", template: badge_html)

      # Update floating toast notification (only if toast is enabled for this event and recipient is not the actor)
      if should_display_toast?(user)
        toast_html = ApplicationController.render(
          partial: "layouts/shared_components/notification_toast",
          locals: { notification: notification }
        )
        streams << Turbo::StreamsChannel.turbo_stream_action_tag(:update, target: "notification_toast", template: toast_html)
      end
    end

    # Broadcast atomic Turbo Stream batch to user's private notification channel
    Turbo::StreamsChannel.broadcast_stream_to(
      [ user, :notifications ],
      content: streams.join
    )
  rescue StandardError => e
    Rails.logger.error("[DeliveryMethods::TurboStream] Failed to broadcast notification stream to user #{user.id}: #{e.class}: #{e.message}")
  end

  private

  def should_display_toast?(user)
    target_event = notification&.event
    return false if target_event.respond_to?(:show_toast?) && !target_event.show_toast?

    params = target_event&.params || {}
    if params.is_a?(Hash)
      return false if params[:show_toast] == false

      # Suppress toast if this recipient is the actor of the event
      actor_id = params[:actor_id] || params[:paid_by_id]
      return false if actor_id.present? && actor_id.to_s == user.id.to_s
    end

    true
  end
end
