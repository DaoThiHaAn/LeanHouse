require "test_helper"
require "minitest/mock"

class BroadcastCustomNotificationJobTest < ActiveJob::TestCase
  setup do
    @admin = Admin.create!(
      email: "admin_job@leanhouse.vn",
      fullname: "Admin Job Tester",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @landlord = User.create!(
      fullname: "Chu Nha A",
      tel: "0902221111",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 40.years.ago.to_date,
      address: "10 Le Duan",
      tel_verified_at: Time.current
    )

    @tenant = User.create!(
      fullname: "Khach Thue B",
      tel: "0902222222",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 25.years.ago.to_date,
      address: "20 Le Duan",
      tel_verified_at: Time.current
    )
  end

  test "delivers to all active non-admin users" do
    assert_difference -> { Noticed::Notification.count }, 2 do
      BroadcastCustomNotificationJob.perform_now(
        admin_id: @admin.id,
        target_audience: "all",
        title: "Toàn hệ thống",
        message: "Nội dung cho tất cả người dùng",
        level: "info"
      )
    end

    event = Noticed::Event.where(type: "CustomAnnouncementNotifier").last
    assert_equal 2, event.notifications_count
    assert_equal "all", event.params[:target_audience]
    assert_includes event.notifications.map(&:recipient_id), @landlord.id
    assert_includes event.notifications.map(&:recipient_id), @tenant.id
  end

  test "delivers strictly to landlords when target_audience is landlords" do
    assert_difference -> { @landlord.notifications.count }, 1 do
      assert_no_difference -> { @tenant.notifications.count } do
        BroadcastCustomNotificationJob.perform_now(
          admin_id: @admin.id,
          target_audience: "landlords",
          title: "Chỉ cho Chủ trọ",
          message: "Nội dung dành riêng cho chủ nhà trọ",
          level: "warning"
        )
      end
    end
  end

  test "delivers strictly to tenants when target_audience is tenants" do
    assert_difference -> { @tenant.notifications.count }, 1 do
      assert_no_difference -> { @landlord.notifications.count } do
        BroadcastCustomNotificationJob.perform_now(
          admin_id: @admin.id,
          target_audience: "tenants",
          title: "Chỉ cho Khách thuê",
          message: "Nội dung dành riêng cho khách thuê",
          level: "urgent"
        )
      end
    end
  end

  test "DeliveryMethods::TurboStream broadcasts multi-target turbo streams including toast and notification center" do
    BroadcastCustomNotificationJob.perform_now(
      admin_id: @admin.id,
      target_audience: "tenants",
      title: "Thông báo test stream",
      message: "Nội dung thông báo stream",
      level: "urgent"
    )

    notification = @tenant.notifications.last
    assert_not_nil notification

    broadcasted_streams = []
    Turbo::StreamsChannel.stub(:broadcast_stream_to, ->(streamables, content:) {
      broadcasted_streams << { streamables: streamables, content: content }
    }) do
      DeliveryMethods::TurboStream.perform_now(:turbo_stream, notification)
    end

    assert_equal 1, broadcasted_streams.size
    content = broadcasted_streams.first[:content]
    assert_match(/target="notification_box"/, content)
    assert_match(/target="notifications_list_items"/, content)
    assert_match(/target="notifications_empty_state"/, content)
    assert_match(/target="unread_filter_badge"/, content)
    assert_match(/target="notification_toast"/, content)
    assert_match(/notification-toast-wrapper/, content)
    assert_match(/Thông báo test stream/, content)
  end
end
