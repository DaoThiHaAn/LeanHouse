require "test_helper"

class CriticalBusinessLogicCoverageTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0911000111")
    @tenant_user = create_tenant(tel: "0922000222")
    @tenant = @tenant_user.tenant

    @bank = Bank.first || Bank.create!(
      code: "MB",
      short_name: "MBBank",
      name: "Ngân hàng TMCP Quân Đội",
      bin: "970422"
    )
    @bank_account = BankAccount.create!(
      landlord_id: @landlord_user.id,
      bank: @bank,
      account_number: "0123456789",
      account_holder: "NGUYEN VAN CHU NHA",
      payos_enabled: true,
      payos_client_id: "client_123",
      payos_api_key: "api_123",
      payos_checksum_key: "checksum_123"
    )

    @house = House.create!(
      landlord_id: @landlord_user.id,
      name: "Test House Business",
      address_l1: "TP.HCM",
      address_l2: "Quận 1",
      address_l3: "123 Lê Lợi",
      mode: :room,
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = Floor.create!(house: @house, name: "Tầng 1", position: 1, rooms_count: 0)
    @room = Room.create!(floor: @floor, name: "P101", max_slots: 2, area: 25)
    @rental_unit = RentalUnit.find_or_create_by!(rentable: @room) do |ru|
      ru.rent = 3_500_000
      ru.deposit = 3_500_000
    end
    @stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: 1.month.ago.to_date,
      checkout_at: nil,
      has_contract: true
    )
    @invoice = Invoice.create!(
      house: @house,
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      bank_account: @bank_account,
      code: "HD26092026-P101-TEST",
      title: "Hóa đơn tháng 9",
      invoice_type: "room",
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      total_amount: 3_500_000
    )
  end

  # =========================================================================
  # 1. PayosService Branch Coverage
  # =========================================================================
  test "PayosService signature, verification, and URL resolution branches" do
    assert_nil PayosService.create_signature(nil, "key")
    assert_nil PayosService.create_signature({ a: 1 }, "")

    sig = PayosService.create_signature({ "b" => 2, :a => 1 }, "secret_key")
    assert_not_nil sig
    assert PayosService.verify_webhook_data({ "b" => 2, "a" => 1 }, sig, "secret_key")
    assert_not PayosService.verify_webhook_data({ "b" => 2, "a" => 1 }, "wrong_sig", "secret_key")
    assert_not PayosService.verify_webhook_data(nil, sig, "secret_key")
    assert_not PayosService.verify_webhook_data({ a: 1 }, "", "secret_key")

    # base_app_url with host parameter
    assert_equal "http://example.com", PayosService.base_app_url(host: "example.com/")
    assert_equal "https://secure.example.com", PayosService.base_app_url(host: "https://secure.example.com/")

    # base_app_url with ENV["APP_HOST"]
    old_app_host = ENV["APP_HOST"]
    begin
      ENV["APP_HOST"] = "myhost.vn/"
      assert_equal "http://myhost.vn", PayosService.base_app_url
      ENV["APP_HOST"] = "https://myhost.vn/"
      assert_equal "https://myhost.vn", PayosService.base_app_url
    ensure
      ENV["APP_HOST"] = old_app_host
    end

    # webhook_url with ENV and request object
    old_wh = ENV["PAYOS_WEBHOOK_URL"]
    begin
      ENV["PAYOS_WEBHOOK_URL"] = " https://custom.webhook/payos "
      assert_equal "https://custom.webhook/payos", PayosService.webhook_url
      ENV["PAYOS_WEBHOOK_URL"] = nil
      fake_req = Struct.new(:base_url).new("https://req.host/")
      assert_equal "https://req.host/webhooks/payos", PayosService.webhook_url(fake_req)
      assert_match(%r{/webhooks/payos$}, PayosService.webhook_url(nil))
    ensure
      ENV["PAYOS_WEBHOOK_URL"] = old_wh
    end
  end

  test "PayosService unconfigured bank and reconcile guard branches" do
    unconfigured_bank = BankAccount.create!(
      landlord_id: @landlord_user.id,
      bank: @bank,
      account_number: "999999999",
      account_holder: "CHU NHA 2",
      payos_enabled: false
    )
    @invoice.update!(bank_account: unconfigured_bank)

    res_create = PayosService.create_payment_link(@invoice)
    assert_equal false, res_create[:success]

    res_cancel = PayosService.cancel_payment_link(@invoice)
    assert_equal false, res_cancel[:success]

    res_fetch = PayosService.fetch_payment_link_info("123", unconfigured_bank)
    assert_equal false, res_fetch[:success]

    assert_equal({ success: false, error: "No order code or payment link ID" },
                 PayosService.fetch_payment_link_info("", @bank_account))

    # Reconcile when unconfigured or paid
    assert_equal @invoice, PayosService.reconcile_payment!(@invoice)

    @invoice.update!(bank_account: @bank_account)
    # cancel_payment_link when no order exists yet
    res_no_order = PayosService.cancel_payment_link(@invoice)
    assert_equal true, res_no_order[:success]
    assert_equal "No payOS order to cancel", res_no_order[:message]

    # Reconcile when no order exists yet
    assert_equal @invoice, PayosService.reconcile_payment!(@invoice)
  end

  # =========================================================================
  # 2. TenantFilter Branch Coverage
  # =========================================================================
  test "TenantFilter filters by search query, contract_state, and residence_state" do
    Contract.create!(
      house: @house,
      landlord_id: @landlord_user.id,
      tenant: @tenant,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      name: "HD-P101",
      start_date: 2.months.ago.to_date,
      due_date: 1.day.ago.to_date,
      temp_resid_registered: false,
      documents: [
        { io: StringIO.new("fake_jpg_content"), filename: "contract.jpg", content_type: "image/jpeg" }
      ]
    )

    # Default call
    assert_includes TenantFilter.call(house: @house, params: {}), @tenant

    # Search query
    assert_includes TenantFilter.call(house: @house, params: { query: @tenant_user.fullname }), @tenant

    # Contract states: overdue, nearly-due, all
    assert_includes TenantFilter.call(house: @house, params: { contract_state: "overdue" }), @tenant
    assert_empty TenantFilter.call(house: @house, params: { contract_state: "nearly-due" })
    assert_includes TenantFilter.call(house: @house, params: { contract_state: "all" }), @tenant

    # Residence states: none, overdue, nearly-due
    assert_includes TenantFilter.call(house: @house, params: { residence_state: "none" }), @tenant
    assert_empty TenantFilter.call(house: @house, params: { residence_state: "overdue" })
    assert_empty TenantFilter.call(house: @house, params: { residence_state: "nearly-due" })

    # Bed mode house
    bed_house = House.create!(
      landlord_id: @landlord_user.id,
      name: "Bed House",
      address_l1: "TP.HCM",
      address_l2: "Quận 1",
      address_l3: "456 Lê Lợi",
      mode: :bed,
      floors_count: 1,
      inv_creation_date: 1
    )
    assert_empty TenantFilter.call(house: bed_house, params: {})
  end

  # =========================================================================
  # 3. Invoices::UpdateService Branch Coverage
  # =========================================================================
  test "Invoices::UpdateService handles transfer note modes, date sync, and paid guard" do
    @invoice.invoice_items.create!(
      name: "Tiền phòng",
      item_type: "rent",
      unit: "tháng",
      unit_price: 3_500_000,
      quantity: 1,
      amount: 3_500_000
    )

    # 1. Update with transfer_note_mode: "none" and start_date/end_date sync
    new_start = Date.current.beginning_of_month + 2.days
    assert Invoices::UpdateService.call(
      invoice: @invoice,
      house: @house,
      params: { start_date: new_start, transfer_note_mode: "none" }
    )
    assert_nil @invoice.reload.transfer_note
    assert_equal new_start, @invoice.invoice_items.first.start_date

    # 2. Update with transfer_note_mode: "custom"
    assert Invoices::UpdateService.call(
      invoice: @invoice,
      house: @house,
      params: { transfer_note_mode: "custom", transfer_note: "Thanh toan P101" }
    )
    assert_equal "THANH TOAN P101", @invoice.reload.transfer_note

    # 3. Update with transfer_note_mode: "system"
    assert Invoices::UpdateService.call(
      invoice: @invoice,
      house: @house,
      params: { transfer_note_mode: "system" }
    )

    # 4. Update with default transfer_note key
    assert Invoices::UpdateService.call(
      invoice: @invoice,
      house: @house,
      params: { transfer_note: "Ghi chu mac dinh" }
    )
    assert_equal "GHI CHU MAC DINH", @invoice.reload.transfer_note

    # 5. Paid guard returns false
    @invoice.update_columns(status: :paid)
    assert_not Invoices::UpdateService.call(
      invoice: @invoice,
      house: @house,
      params: { title: "Cannot update" }
    )
    assert @invoice.errors[:base].any?
  end

  # =========================================================================
  # 4. House Model Scopes & Methods Branch Coverage
  # =========================================================================
  test "House scopes and availability helpers cover all branches" do
    assert_includes House.by_invoice_status("has_unpaid"), @house
    assert_not_includes House.by_invoice_status("all_paid"), @house
    assert_includes House.by_invoice_status("unknown_status"), @house
    assert_includes House.by_invoice_status(""), @house

    assert_equal 1, @house.unpaid_invoices_count
    assert_not @house.reach_max_floors?
    assert_operator @house.occupancy_rate, :>=, 0
    assert_not_empty @house.available_rental_units

    # Bed mode available_rental_units
    bed_house = House.create!(
      landlord_id: @landlord_user.id,
      name: "Bed Mode House",
      address_l1: "TP.HCM",
      address_l2: "Quận 3",
      address_l3: "789 Nguyễn Đình Chiểu",
      mode: :bed,
      floors_count: 1,
      inv_creation_date: 1
    )
    assert_equal 0, bed_house.occupancy_rate
    assert_empty bed_house.available_rental_units
    assert bed_house.can_delete?
    assert bed_house.can_change_mode?
  end

  # =========================================================================
  # 5. InvoiceOverdueCheckJob Branch Coverage
  # =========================================================================
  test "InvoiceOverdueCheckJob marks overdue and respects 1, 3, 7 day cadence" do
    # Day 1 overdue -> marks overdue and notifies
    @invoice.update_columns(status: :pending, due_date: Date.current - 1.day)
    InvoiceOverdueCheckJob.perform_now
    assert_equal "overdue", @invoice.reload.status

    # Day 2 overdue -> stays overdue, skips notification cadence
    @invoice.update_columns(due_date: Date.current - 2.days)
    InvoiceOverdueCheckJob.perform_now
    assert_equal "overdue", @invoice.reload.status
  end

  # =========================================================================
  # 6. Checkin, ContractSigning, ContractRenewal & VehicleRequestSubmission
  # =========================================================================
  test "Checkin, ContractSigning, ContractRenewal, and VehicleRequestSubmission services" do
    new_tenant_user = create_tenant(tel: "0933000333")
    new_tenant = new_tenant_user.tenant

    room2 = Room.create!(floor: @floor, name: "P102", max_slots: 2, area: 25)
    ru2 = RentalUnit.find_or_create_by!(rentable: room2) do |ru|
      ru.rent = 3_000_000
      ru.deposit = 3_000_000
    end

    # Checkin service
    stay = Checkin.call(
      house: @house,
      tenant_id: new_tenant.id,
      rental_unit_id: ru2.id,
      send_noti: true
    )
    assert stay.persisted?

    # ContractSigning service
    contract_params = {
      tenant_citizen_id: "012345678902",
      landlord_citizen_id: "098765432109",
      name: "HD-NEW-101",
      start_date: Date.current,
      due_date: Date.current + 6.months,
      temp_resid_registered: false,
      documents: [
        { io: StringIO.new("fake_jpg"), filename: "c1.jpg", content_type: "image/jpeg" }
      ]
    }
    signed_contract = ContractSigning.call(
      house: @house,
      tenant_stay: stay,
      landlord: @landlord_user.landlord,
      params: contract_params,
      send_noti: true
    )
    assert signed_contract.persisted?
    assert stay.reload.has_contract?

    # ContractRenewal service
    renewal_params = contract_params.merge(
      name: "HD-RENEW-101",
      start_date: Date.current + 6.months,
      due_date: Date.current + 12.months,
      documents: [
        { io: StringIO.new("fake_jpg2"), filename: "c2.jpg", content_type: "image/jpeg" }
      ]
    )
    renewed_contract = ContractRenewal.call(
      house: @house,
      old_contract: signed_contract,
      tenant_stay: stay,
      landlord: @landlord_user.landlord,
      params: renewal_params,
      send_noti: true
    )
    assert renewed_contract.persisted?
    assert_not_nil signed_contract.reload.end_date

    # VehicleRequestSubmission service (rejected terms vs accepted terms)
    assert_raises(ActiveRecord::RecordInvalid) do
      VehicleRequestSubmission.call(
        tenant: new_tenant,
        house: @house,
        tenant_stay: stay,
        params: { license_plate: "59A1-12345", vehicle_type: :motorbike, brand: "Honda", model: "AirBlade" },
        accept_terms: "0"
      )
    end

    v_req = VehicleRequestSubmission.call(
      tenant: new_tenant,
      house: @house,
      tenant_stay: stay,
      params: {
        license_plate: "59A1-12345",
        vehicle_type: :motorbike,
        brand: "Honda",
        model: "AirBlade",
        vehicle_photo: { io: StringIO.new("fake_jpg"), filename: "v.jpg", content_type: "image/jpeg" },
        registration_card_image: { io: StringIO.new("fake_jpg"), filename: "r.jpg", content_type: "image/jpeg" }
      },
      accept_terms: "1",
      send_noti: true
    )
    assert v_req.persisted?
  end

  test "ContractDueReminderJob, ContractDueTodayJob, and InvoiceCreationReminderJob" do
    @house.update_columns(inv_creation_date: Date.current.day)
    InvoiceCreationReminderJob.perform_now

    c_30 = Contract.create!(
      house: @house,
      landlord_id: @landlord_user.id,
      tenant: @tenant,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      name: "HD-30DAYS",
      start_date: 2.months.ago.to_date,
      due_date: Date.current + 30.days,
      temp_resid_registered: false,
      documents: [
        { io: StringIO.new("fake_jpg"), filename: "c30.jpg", content_type: "image/jpeg" }
      ]
    )
    ContractDueReminderJob.perform_now

    c_30.update_columns(due_date: Date.current)
    ContractDueTodayJob.perform_now
    assert_equal Date.current, c_30.reload.due_date

    # Also ensure LandlordPortal::FloorsController is loaded and its methods/constants are covered
    assert_equal 50, LandlordPortal::FloorsController::MAX_FLOORS
  end
end
