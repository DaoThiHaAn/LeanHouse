require "test_helper"

class AdminPortal::NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = Admin.create!(
      email: "admin_notify@leanhouse.vn",
      fullname: "Admin Notify",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @landlord_user = User.create!(
      fullname: "Nguyen Van ChuTro",
      tel: "0901234001",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "100 Le Loi, Q1",
      tel_verified_at: Time.current
    )

    @tenant_user = User.create!(
      fullname: "Tran Thi KhachThue",
      tel: "0901234002",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "200 Nguyen Hue, Q1",
      tel_verified_at: Time.current
    )
  end

  def login_as(admin)
    post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
  end

  test "unauthenticated user cannot access notifications index or new" do
    get admin_notifications_url
    assert_redirected_to admin_login_url

    get new_admin_notification_url
    assert_redirected_to admin_login_url
  end

  test "admin can view notifications index with empty and populated states" do
    login_as(@admin)

    get admin_notifications_url
    assert_response :success
    assert_select ".admin-title", text: I18n.t("admin.notifications.title")
    assert_select "a[href=?]", new_admin_notification_path

    # Create a broadcast
    BroadcastCustomNotificationJob.perform_now(
      admin_id: @admin.id,
      target_audience: "all",
      title: "Thông báo bảo trì hệ thống",
      message: "Hệ thống sẽ bảo trì từ 01:00 đến 03:00.",
      level: "warning"
    )

    get admin_notifications_url
    assert_response :success
    assert_select "table tbody tr", minimum: 1
    assert_includes response.body, "Thông báo bảo trì hệ thống"
    assert_select "select[name='level']"
    assert_select "select[name='audience']"
  end

  test "admin can filter notifications by priority level and audience" do
    login_as(@admin)

    # 1. Info to Landlords
    BroadcastCustomNotificationJob.perform_now(
      admin_id: @admin.id,
      target_audience: "landlords",
      title: "Chính sách thuế mới",
      message: "Chi tiết quy định mới về thuế cho chủ nhà.",
      level: "info"
    )

    # 2. Urgent to Tenants
    BroadcastCustomNotificationJob.perform_now(
      admin_id: @admin.id,
      target_audience: "tenants",
      title: "Khẩn cấp kiểm tra PCCC",
      message: "Kiểm tra hệ thống báo cháy khu trọ.",
      level: "urgent"
    )

    # Filter by level=urgent
    get admin_notifications_url, params: { level: "urgent" }
    assert_response :success
    assert_includes response.body, "Khẩn cấp kiểm tra PCCC"
    assert_not_includes response.body, "Chính sách thuế mới"

    # Filter by audience=landlords
    get admin_notifications_url, params: { audience: "landlords" }
    assert_response :success
    assert_includes response.body, "Chính sách thuế mới"
    assert_not_includes response.body, "Khẩn cấp kiểm tra PCCC"

    # Filter by combination that has no matches
    get admin_notifications_url, params: { level: "urgent", audience: "landlords" }
    assert_response :success
    assert_not_includes response.body, "Chính sách thuế mới"
    assert_not_includes response.body, "Khẩn cấp kiểm tra PCCC"
    assert_includes response.body, I18n.t("admin.notifications.filter.no_matching_title")

    # Filter with Turbo-Frame header renders only the table partial without full layout
    get admin_notifications_url, params: { level: "urgent" }, headers: { "Turbo-Frame" => "admin_notifications_table" }
    assert_response :success
    assert_select "turbo-frame#admin_notifications_table"
    assert_select "header", count: 0
    assert_select ".admin-title", count: 0
    assert_includes response.body, "Khẩn cấp kiểm tra PCCC"
  end

  test "admin can view new notification form" do
    login_as(@admin)

    get new_admin_notification_url
    assert_response :success
    assert_select "form#broadcastNotificationForm"
    assert_select "input[name='target_audience'][value='all']"
    assert_select "input[name='target_audience'][value='landlords']"
    assert_select "input[name='target_audience'][value='tenants']"
    assert_select "input[name='title']"
    assert_select "textarea[name='message']"
    assert_select "#confirmBroadcastModal"
    assert_includes response.body, I18n.t("admin.notifications.immutability_warning_title")
  end

  test "admin cannot create notification with blank title or message" do
    login_as(@admin)

    assert_no_enqueued_jobs do
      post admin_notifications_url, params: {
        target_audience: "all",
        title: "",
        message: "",
        level: "info"
      }
    end

    assert_response :unprocessable_entity
    assert_equal I18n.t("admin.notifications.missing_fields"), flash[:alert]
  end

  test "admin creates broadcast enqueues job and redirects to index" do
    login_as(@admin)

    assert_enqueued_with(job: BroadcastCustomNotificationJob) do
      post admin_notifications_url, params: {
        target_audience: "landlords",
        title: "Chính sách mới cho Chủ nhà",
        message: "Kính gửi quý chủ nhà nội dung cập nhật.",
        url: "/terms-of-use",
        level: "info"
      }
    end

    assert_redirected_to admin_notifications_url
    follow_redirect!
    assert_includes flash[:notice], "1" # 1 landlord in setup
  end

  test "duplicate rapid broadcasts within 5 seconds are ignored" do
    login_as(@admin)

    # Perform the first broadcast synchronously so the event is recorded in DB
    BroadcastCustomNotificationJob.perform_now(
      admin_id: @admin.id,
      target_audience: "landlords",
      title: "Chính sách mới cho Chủ nhà",
      message: "Kính gửi quý chủ nhà nội dung cập nhật.",
      level: "info"
    )

    # Subsequent POST with identical params within 5s should not enqueue another job
    assert_no_enqueued_jobs do
      post admin_notifications_url, params: {
        target_audience: "landlords",
        title: "Chính sách mới cho Chủ nhà",
        message: "Kính gửi quý chủ nhà nội dung cập nhật.",
        level: "info"
      }
    end

    assert_redirected_to admin_notifications_url
  end

  test "admin can view show page of broadcast event" do
    login_as(@admin)

    BroadcastCustomNotificationJob.perform_now(
      admin_id: @admin.id,
      target_audience: "all",
      title: "Cảnh báo an ninh PCCC",
      message: "Vui lòng tắt các thiết bị điện trước khi ra khỏi phòng.",
      url: "/report-issues",
      level: "urgent"
    )

    event = Noticed::Event.where(type: "CustomAnnouncementNotifier").last
    assert_not_nil event

    get admin_notification_url(event)
    assert_response :success
    assert_includes response.body, "Cảnh báo an ninh PCCC"
    assert_includes response.body, I18n.t("admin.notifications.immutable_badge")
    assert_select "table tbody tr", minimum: 2 # 1 landlord + 1 tenant
  end

  test "notifications do not support edit, update, or destroy routes" do
    login_as(@admin)

    assert_raises(ActionController::UrlGenerationError) do
      url_for(controller: "admin_portal/notifications", action: "edit", id: 1)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/notifications/1", method: :patch)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin/notifications/1", method: :delete)
    end
  end
end
