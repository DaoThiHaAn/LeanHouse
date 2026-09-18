# frozen_string_literal: true

require "test_helper"

class InvoiceIssuedNotifierTest < ActiveSupport::TestCase
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
      tenant: @tenant,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      subtotal: 2000000,
      total_amount: 2000000
    )
  end

  test "notification url directs to tenant invoice show view" do
    InvoiceIssuedNotifier.with(
      invoice: @invoice,
      invoice_id: @invoice.id,
      code: @invoice.code,
      room_name: @room.title_name,
      month: @invoice.billing_month.strftime("%m/%Y"),
      raw_month: @invoice.billing_month.strftime("%Y-%m"),
      amount: "2,000,000 đ",
      due_date: @invoice.due_date.strftime("%d/%m/%Y"),
      house_id: @house.id
    ).deliver(@tenant_user)

    notification = @tenant_user.notifications.last
    assert_not_nil notification
    assert_equal Rails.application.routes.url_helpers.tenant_invoice_path(@invoice), notification.url
  end
end
