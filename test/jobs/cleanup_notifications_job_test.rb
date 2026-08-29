require "test_helper"

class CleanupNotificationsJobTest < ActiveJob::TestCase
  setup do
    @user = User.create!(
      fullname: "Le Van B",
      tel: "0908887777",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "456 Side St",
      tel_verified_at: Time.current
    )

    # 1. Read notification older than 30 days (35 days old) -> Should be deleted
    TelephoneChangedNotifier.with(new_tel: "0900000001").deliver(@user)
    @read_old = @user.notifications.order(:id).last
    @read_old.update_columns(created_at: 35.days.ago, read_at: 34.days.ago)
    @read_old.event.update_columns(created_at: 35.days.ago)

    # 2. Read notification within 30 days (10 days old) -> Should be kept
    TelephoneChangedNotifier.with(new_tel: "0900000002").deliver(@user)
    @read_recent = @user.notifications.order(:id).last
    @read_recent.update_columns(created_at: 10.days.ago, read_at: 9.days.ago)
    @read_recent.event.update_columns(created_at: 10.days.ago)

    # 3. Unread notification older than 180 days (200 days old) -> Should be deleted
    TelephoneChangedNotifier.with(new_tel: "0900000003").deliver(@user)
    @unread_old = @user.notifications.order(:id).last
    @unread_old.update_columns(created_at: 200.days.ago, read_at: nil)
    @unread_old.event.update_columns(created_at: 200.days.ago)

    # 4. Unread notification within 180 days (40 days old) -> Should be kept
    TelephoneChangedNotifier.with(new_tel: "0900000004").deliver(@user)
    @unread_recent = @user.notifications.order(:id).last
    @unread_recent.update_columns(created_at: 40.days.ago, read_at: nil)
    @unread_recent.event.update_columns(created_at: 40.days.ago)
  end

  test "perform deletes old read (>30d) and old unread (>180d) notifications and orphaned events" do
    read_old_event_id = @read_old.event_id
    unread_old_event_id = @unread_old.event_id

    CleanupNotificationsJob.perform_now(read_days: 30, unread_days: 180)

    # Verify notifications
    assert_not Noticed::Notification.exists?(@read_old.id), "Old read notification should be deleted"
    assert Noticed::Notification.exists?(@read_recent.id), "Recent read notification should be kept"
    assert_not Noticed::Notification.exists?(@unread_old.id), "Old unread notification should be deleted"
    assert Noticed::Notification.exists?(@unread_recent.id), "Recent unread notification should be kept"

    # Verify orphaned events
    assert_not Noticed::Event.exists?(read_old_event_id), "Orphaned event for old read notification should be deleted"
    assert_not Noticed::Event.exists?(unread_old_event_id), "Orphaned event for old unread notification should be deleted"
    assert Noticed::Event.exists?(@read_recent.event_id), "Event for recent read notification should be kept"
    assert Noticed::Event.exists?(@unread_recent.event_id), "Event for recent unread notification should be kept"
  end
end
