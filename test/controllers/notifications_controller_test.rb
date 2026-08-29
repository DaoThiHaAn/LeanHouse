require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = User.create!(
      fullname: "Nguyen Van A",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "123 Main St",
      tel_verified_at: Time.current
    )

    # Deliver some notifications
    TelephoneChangedNotifier.with(new_tel: "0909999991").deliver(@user)
    TelephoneChangedNotifier.with(new_tel: "0909999992").deliver(@user)

    @notification1 = @user.notifications.first
    @notification2 = @user.notifications.second

    # Mark the second notification as read
    @notification2.update!(read_at: Time.current)
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "index redirects unauthenticated user to login" do
    get notifications_path
    assert_redirected_to login_path
  end

  test "index renders successfully when authenticated and shows all notifications" do
    sign_in_as(@user)

    get notifications_path
    assert_response :success
    assert_includes response.body, I18n.t("noti.notification_center")
    assert_select ".notifications-page .notification-full-message", count: 2
  end

  test "index filter=unread shows only unread notifications" do
    sign_in_as(@user)

    get notifications_path, params: { filter: "unread" }
    assert_response :success
    assert_select ".notifications-page .notification-full-message", text: /0909999991/, count: 1
    assert_select ".notifications-page .notification-full-message", text: /0909999992/, count: 0
  end

  test "index filter=read shows only read notifications" do
    sign_in_as(@user)

    get notifications_path, params: { filter: "read" }
    assert_response :success
    assert_select ".notifications-page .notification-full-message", text: /0909999992/, count: 1
    assert_select ".notifications-page .notification-full-message", text: /0909999991/, count: 0
  end

  test "mark_as_read marks a notification as read via HTML" do
    sign_in_as(@user)

    assert_nil @notification1.read_at

    patch mark_as_read_notification_path(@notification1)
    assert_response :redirect

    assert_not_nil @notification1.reload.read_at
  end

  test "mark_as_read responds with Turbo Stream replacing notification card and updating dropdown" do
    sign_in_as(@user)

    assert_nil @notification1.read_at

    patch mark_as_read_notification_path(@notification1), as: :turbo_stream
    assert_response :success
    assert_match(/turbo-stream action="update" target="notification_box"/, response.body)
    assert_match(/turbo-stream action="replace" target="#{dom_id(@notification1)}"/, response.body)
    assert_match(/turbo-stream action="update" target="unread_filter_badge"/, response.body)

    assert_not_nil @notification1.reload.read_at
  end

  test "mark_all_as_read marks all unread notifications as read via HTML" do
    sign_in_as(@user)

    assert_equal 1, @user.notifications.unread.count

    patch mark_all_as_read_notifications_path
    assert_response :redirect

    assert_equal 0, @user.notifications.unread.count
  end

  test "mark_all_as_read responds with Turbo Stream updating page content and dropdown" do
    sign_in_as(@user)

    assert_equal 1, @user.notifications.unread.count

    patch mark_all_as_read_notifications_path, as: :turbo_stream
    assert_response :success
    assert_match(/turbo-stream action="update" target="notification_box"/, response.body)
    assert_match(/turbo-stream action="update" target="notifications_page_content"/, response.body)

    assert_equal 0, @user.notifications.unread.count
  end
end
