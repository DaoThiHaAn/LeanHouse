require "test_helper"

class BroadcastNotificationFormTest < ActiveSupport::TestCase
  setup do
    @landlord = User.create!(
      fullname: "Chủ Nhà Mẫu",
      tel: "0911000001",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Đường A",
      password: "Password123!",
      password_confirmation: "Password123!",
      tel_verified_at: Time.current
    )

    @tenant = User.create!(
      fullname: "Khách Thuê Mẫu",
      tel: "0911000002",
      role: "tenant",
      sex: "female",
      bday: 20.years.ago.to_date,
      address: "456 Đường B",
      password: "Password123!",
      password_confirmation: "Password123!",
      tel_verified_at: Time.current
    )
  end

  test "squishes title, message, and url removing extra spaces and tabs" do
    form = BroadcastNotificationForm.new(
      title: "   Thông   báo   bảo trì    hệ  thống   ",
      message: "   Nội   dung  \n  chi   tiết  \t  thông   báo.   ",
      url: "   /terms-of-use   ",
      level: "  warning  ",
      target_audience: "  landlords  "
    )

    assert_equal "Thông báo bảo trì hệ thống", form.title
    assert_equal "Nội dung chi tiết thông báo.", form.message
    assert_equal "/terms-of-use", form.url
    assert_equal "warning", form.level
    assert_equal "landlords", form.target_audience
  end

  test "converts blank url to nil when squished" do
    form = BroadcastNotificationForm.new(url: "    \t  \n  ")
    assert_nil form.url
  end

  test "defaults target_audience to all and level to info" do
    form = BroadcastNotificationForm.new
    assert_equal "all", form.target_audience
    assert_equal "info", form.level

    invalid_form = BroadcastNotificationForm.new(target_audience: "unknown", level: "critical")
    assert_equal "all", invalid_form.target_audience
    assert_equal "info", invalid_form.level
  end

  test "validates required title and message" do
    form = BroadcastNotificationForm.new(title: "   ", message: "   ")
    assert_not form.valid?
    assert form.errors[:title].present?
    assert form.errors[:message].present?

    form.title = "A" * 151
    form.message = "Valid message"
    assert_not form.valid?
    assert form.errors[:title].present?

    form.title = "Tiêu đề hợp lệ"
    assert form.valid?
  end

  test "resolves audience_scope and recipient_count correctly" do
    form_all = BroadcastNotificationForm.new(target_audience: "all")
    assert_includes form_all.audience_scope, @landlord
    assert_includes form_all.audience_scope, @tenant
    assert form_all.recipient_count >= 2

    form_landlords = BroadcastNotificationForm.new(target_audience: "landlords")
    assert_includes form_landlords.audience_scope, @landlord
    assert_not_includes form_landlords.audience_scope, @tenant

    form_tenants = BroadcastNotificationForm.new(target_audience: "tenants")
    assert_includes form_tenants.audience_scope, @tenant
    assert_not_includes form_tenants.audience_scope, @landlord
  end
end
