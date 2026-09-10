class BroadcastCustomNotificationJob < ApplicationJob
  queue_as :default

  def perform(admin_id:, target_audience:, title:, message:, url: nil, level: "info")
    admin = Admin.find_by(id: admin_id)

    form = BroadcastNotificationForm.new(
      target_audience: target_audience,
      title: title,
      message: message,
      url: url,
      level: level
    )

    scope = form.audience_scope
    return if scope.none?

    notifier = CustomAnnouncementNotifier.with(
      record: admin,
      title: form.title,
      message: form.message,
      url: form.url,
      level: form.level,
      sender_name: admin&.fullname || "LeanHouse Admin",
      target_audience: form.target_audience
    )

    notifier.deliver(scope)
  end
end
