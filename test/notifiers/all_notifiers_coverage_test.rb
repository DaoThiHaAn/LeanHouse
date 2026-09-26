# frozen_string_literal: true

require "test_helper"

class AllNotifiersCoverageTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0908881111")
    @tenant_user = create_tenant(tel: "0908882222")
    @roommate_user = create_tenant(tel: "0908883333", fullname: "Ban Cung Phong")

    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Notifier Coverage House",
      mode: :room,
      address_l1: "100 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 0)
    @room = @floor.rooms.create!(name: "101", max_slots: 4, area: 25.0)
    @room.create_rental_unit!(rent: 4_000_000, deposit: 4_000_000)

    @tenant_stay = TenantStay.create!(
      tenant: @tenant_user.tenant,
      rental_unit: @room.rental_unit,
      checkin_at: 2.months.ago,
      has_contract: true
    )

    @contract = Contract.new(
      house: @house,
      landlord: @landlord_user.landlord,
      tenant: @tenant_user.tenant,
      name: "HD-COV-01",
      landlord_citizen_id: "079199000111",
      tenant_citizen_id: "079201000222",
      start_date: 2.months.ago.to_date,
      due_date: 1.month.from_now.to_date
    )
    @contract.documents.attach(
      io: StringIO.new("contract img"),
      filename: "contract.jpg",
      content_type: "image/jpeg"
    )
    @contract.save!

    @bank = Bank.find_or_create_by!(code: "VCB") do |b|
      b.name = "Vietcombank"
      b.short_name = "Vietcombank"
      b.bin = "970436"
    end
    @bank_account = @landlord_user.landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "1234567890",
      account_holder: "NGUYEN VAN CHU NHA",
      is_default: true
    )

    @invoice = Invoice.create!(
      house: @house,
      room: @room,
      created_by: @landlord_user,
      bank_account: @bank_account,
      invoice_type: :room,
      code: "HD01092026-101-ABCD",
      title: "Hóa đơn 09/2026",
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      due_date: Date.current + 5.days,
      subtotal: 4_000_000,
      total_amount: 4_000_000,
      status: :pending
    )

    @service = @house.services.create!(name: "Điện")
    @variant = @service.service_variants.create!(
      unit: :per_kwh,
      fee: 3_500,
      is_real_time: true
    )
    @log = ServiceUsageLog.create!(
      room: @room,
      service: @service,
      service_variant: @variant,
      service_name: "Điện",
      unit: "kWh",
      unit_price: 3_500,
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      prev_reading: 100,
      latest_reading: 150,
      is_confirmed: true
    )

    @repair_req = RepairRequest.create!(title: "Sửa máy lạnh", content: "Máy lạnh không mát")
    @request = @tenant_user.tenant.requests.create!(
      house: @house,
      requestable: @repair_req,
      status: :pending
    )
  end

  def assert_notifier_renders(notifier_event, recipients = [ @landlord_user, @tenant_user ])
    notifier_event.deliver(recipients)
    Array(recipients).each do |user|
      noti = user.notifications.order(id: :desc).first
      assert_not_nil noti
      assert_not_nil noti.title
      assert_not_nil noti.message
      noti.url
    end
  end

  test "contract notifiers render title, message, and url for both landlord and tenant" do
    common_params = {
      contract: @contract,
      contract_id: @contract.id,
      house_id: @house.id,
      contract_name: @contract.name,
      tenant_name: @tenant_user.fullname,
      due_date: Date.current
    }

    [
      ContractExpiringSoonNotifier,
      ContractClosedNotifier,
      ContractDueTodayNotifier,
      ContractExtendedNotifier,
      ContractOverdueClosedNotifier,
      ContractSignedNotifier,
      ContractUpdatedNotifier
    ].each do |klass|
      assert_notifier_renders(klass.with(**common_params))
    end
  end

  test "invoice notifiers render title, message, and url for landlord, tenant, and roommate" do
    common_inv_params = {
      invoice: @invoice,
      invoice_id: @invoice.id,
      house_id: @house.id,
      house: @house,
      house_name: @house.name,
      code: @invoice.code,
      room_name: @room.title_name,
      month: "09/2026",
      raw_month: "2026-09",
      amount: "4.000.000đ",
      due_date: "15/09/2026",
      explanation: "Sai số tiền",
      actor_name: @landlord_user.fullname,
      method_label: "Chuyển khoản",
      paid_by_role: "tenant"
    }

    assert_notifier_renders(InvoiceCancelledNotifier.with(**common_inv_params), [ @tenant_user ])
    assert_notifier_renders(InvoiceCreationReminderNotifier.with(**common_inv_params), [ @landlord_user ])
    assert_notifier_renders(InvoiceDueTodayNotifier.with(**common_inv_params))
    assert_notifier_renders(InvoiceIssuedNotifier.with(**common_inv_params), [ @tenant_user ])
    assert_notifier_renders(InvoiceOverdueNotifier.with(**common_inv_params))
    assert_notifier_renders(InvoiceUnpaidNotifier.with(**common_inv_params))
    assert_notifier_renders(InvoiceUpdatedNotifier.with(**common_inv_params), [ @tenant_user ])

    # InvoicePaidNotifier: landlord confirmed branch + tenant self paid branch + roommate branch
    assert_notifier_renders(
      InvoicePaidNotifier.with(**common_inv_params, confirmed_by_landlord: true, paid_by_role: "landlord", paid_by_id: @landlord_user.id),
      [ @landlord_user, @tenant_user ]
    )
    assert_notifier_renders(
      InvoicePaidNotifier.with(**common_inv_params, confirmed_by_landlord: false, paid_by_role: "tenant", paid_by_id: @tenant_user.id),
      [ @landlord_user, @tenant_user, @roommate_user ]
    )
  end

  test "tenant, vehicle, service, request, and system notifiers render all branches" do
    stay_params = {
      tenant_stay: @tenant_stay,
      tenant_name: @tenant_user.fullname,
      house: @house.name,
      house_id: @house.id,
      floor: @floor.title_name,
      rental_unit: @room.title_name
    }

    assert_notifier_renders(TenantAddedNotifier.with(**stay_params), [ @tenant_user ])
    assert_notifier_renders(TenantMovedNotifier.with(**stay_params), [ @tenant_user ])
    assert_notifier_renders(TenantRemovedNotifier.with(**stay_params))

    assert_notifier_renders(TelephoneChangedNotifier.with(new_tel: "0909998888"))

    assert_notifier_renders(
      VehicleRemovedNotifier.with(
        tenant_name: @tenant_user.fullname,
        house_name: @house.name,
        house_id: @house.id,
        license_plate: "59X1-99999",
        reason: "Chuyển đi"
      )
    )

    req_params = {
      request: @request,
      tenant_name: @tenant_user.fullname,
      house_name: @house.name,
      location: @room.title_name,
      license_plate: "59X1-99999",
      title: "Hỏng đèn"
    }
    assert_notifier_renders(VehicleRequestCreatedNotifier.with(**req_params))
    assert_notifier_renders(LeaveHouseRequestCreatedNotifier.with(**req_params))
    assert_notifier_renders(RepairRequestCreatedNotifier.with(**req_params))

    %w[approved handling completed rejected unknown].each do |decision|
      assert_notifier_renders(
        RequestResolvedNotifier.with(
          request: @request,
          decision: decision,
          house_name: @house.name,
          title: "Sửa máy lạnh",
          reason: "Không hợp lệ",
          license_plate: "59X1-99999"
        ),
        [ @tenant_user ]
      )
    end

    assert_notifier_renders(ServiceUpdatedNotifier.with(service_name: "Điện", message_text: "Tăng giá"), [ @tenant_user ])
    assert_notifier_renders(ServiceUsageLogConfirmedNotifier.with(log: @log), [ @tenant_user ])
    assert_notifier_renders(ServiceUsageLogRequestedNotifier.with(log: @log), [ @tenant_user ])

    SensitiveFileRemovedNotifier.with(filename: "bad.jpg", reason: "Vi phạm", record_info: "Invoice #1").deliver(@tenant_user)
    sensitive_noti = @tenant_user.notifications.order(id: :desc).first
    assert_not_nil sensitive_noti.title
    assert_not_nil sensitive_noti.message
    assert_nil sensitive_noti.url
    assert_equal "system", sensitive_noti.category

    CustomAnnouncementNotifier.with(title: "Thông báo", message: "Nội dung", url: "/tenant/room").deliver(@tenant_user)
    custom_noti = @tenant_user.notifications.order(id: :desc).first
    assert_equal "Thông báo", custom_noti.title
    assert_equal "Nội dung", custom_noti.message
    assert_equal "/tenant/room", custom_noti.url
    assert_equal "info", custom_noti.level
    assert_equal "LeanHouse Admin", custom_noti.sender_name
  end
end
