# frozen_string_literal: true

require "test_helper"

class InvoicePaidNotifierTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Notifier Test",
      tel: "0901112233",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Notifier Test",
      tel: "0904445566",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "456 Tenant St",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @roommate_user = User.create!(
      fullname: "Roommate Notifier Test",
      tel: "0907778899",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 24.years.ago.to_date,
      address: "456 Tenant St",
      tel_verified_at: Time.current
    )
    @roommate = Tenant.find_or_create_by!(id: @roommate_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "House Notifier Test",
      mode: :room,
      address_l1: "123 St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1)
    @room = @floor.rooms.create!(name: "101", area: 25, max_slots: 2)

    @invoice = Invoice.create!(
      code: "HD-NOTI-01",
      title: "Hóa đơn tiền phòng",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      subtotal: 2000000,
      total_amount: 2000000
    )
  end

  test "delivers natural notification for payOS automated payment" do
    InvoicePaidNotifier.with(
      invoice: @invoice,
      invoice_id: @invoice.id,
      house_id: @house.id,
      code: @invoice.code,
      room_name: @room.title_name,
      amount: "2,000,000 đ",
      paid_by_role: "payos",
      paid_by_id: nil,
      actor_name: "payOS",
      method_label: "Chuyển khoản"
    ).deliver([ @landlord_user, @tenant_user, @roommate_user ])

    landlord_noti = @landlord_user.notifications.last
    assert_not_nil landlord_noti
    assert_includes landlord_noti.message, "Hóa đơn HD-NOTI-01 (Phòng 101) đã được thanh toán thành công với số tiền 2,000,000 đ qua payOS."
    assert_not_includes landlord_noti.message, "Khách thuê payOS"
    assert_not_includes landlord_noti.message, "Vui lòng kiểm tra tài khoản"

    tenant_noti = @tenant_user.notifications.last
    assert_not_nil tenant_noti
    assert_includes tenant_noti.message, "Hóa đơn HD-NOTI-01 (Phòng 101) đã được thanh toán thành công với số tiền 2,000,000 đ qua payOS."
    assert_not_includes tenant_noti.message, "Bạn cùng phòng payOS"

    roommate_noti = @roommate_user.notifications.last
    assert_not_nil roommate_noti
    assert_includes roommate_noti.message, "Hóa đơn HD-NOTI-01 (Phòng 101) đã được thanh toán thành công với số tiền 2,000,000 đ qua payOS."
    assert_not_includes roommate_noti.message, "Bạn cùng phòng payOS"
  end

  test "delivers natural notification for tenant manual payment to roommate" do
    InvoicePaidNotifier.with(
      invoice: @invoice,
      invoice_id: @invoice.id,
      house_id: @house.id,
      code: @invoice.code,
      room_name: @room.title_name,
      amount: "2,000,000 đ",
      paid_by_role: "tenant",
      paid_by_id: @tenant_user.id,
      actor_name: @tenant_user.fullname,
      method_label: "Chuyển khoản"
    ).deliver([ @landlord_user, @tenant_user, @roommate_user ])

    roommate_noti = @roommate_user.notifications.last
    assert_not_nil roommate_noti
    assert_includes roommate_noti.message, "Bạn cùng phòng Tenant Notifier Test đã thanh toán hóa đơn HD-NOTI-01 (Phòng 101) với số tiền 2,000,000 đ qua Chuyển khoản."
    assert_not_includes roommate_noti.message, "hóa đơn phòng"
  end
end
