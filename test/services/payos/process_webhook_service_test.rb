# frozen_string_literal: true

require "test_helper"

class PayosProcessWebhookServiceTest < ActiveSupport::TestCase
  def setup
    @checksum_key = "test_checksum_secret_123"
    @user = User.create!(
      fullname: "Webhook Service Test User",
      tel: "0933445566",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "Hanoi",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
    @bank = Bank.create!(name: "Military Bank", code: "MB", bin: "970422", short_name: "MB")
    @bank_account = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "0933445566",
      account_holder: "SERVICE TEST USER",
      payos_enabled: true,
      payos_client_id: "client-id-xyz",
      payos_api_key: "api-key-xyz",
      payos_checksum_key: @checksum_key
    )

    @house = House.create!(
      landlord: @landlord,
      name: "Service Test House",
      mode: :room,
      address_l1: "789 Street",
      address_l2: "Ward 3",
      address_l3: "District 3",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "301", max_slots: 2, tenants_count: 0, area: 20.0)
    @invoice = @house.invoices.create!(
      room: @room,
      created_by: @user,
      bank_account: @bank_account,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      title: "Tiền phòng T10",
      subtotal: 4000000,
      total_amount: 4000000,
      status: "pending",
      code: "HD-SERVICE-TEST-001"
    )
  end

  test "returns ok on ping / empty payload" do
    result = Payos::ProcessWebhookService.call({})
    assert_equal :ok, result[:status]
    assert_equal I18n.t("invoice.payos.webhook.ping_received"), result[:json][:message]
  end

  test "returns ok when data lacks orderCode" do
    result = Payos::ProcessWebhookService.call({ data: { "amount" => 1000 } })
    assert_equal :ok, result[:status]
    assert_equal I18n.t("invoice.payos.webhook.no_order_code"), result[:json][:message]
  end

  test "returns ok and ignores unknown orderCode" do
    result = Payos::ProcessWebhookService.call({ data: { "orderCode" => 999999999 } })
    assert_equal :ok, result[:status]
    assert_equal I18n.t("invoice.payos.webhook.invoice_not_found"), result[:json][:message]
  end

  test "returns bad_request on signature mismatch" do
    data = {
      "orderCode" => @invoice.payos_order_code,
      "amount" => 4000000,
      "description" => @invoice.payos_transfer_description,
      "reference" => "FT_INVALID"
    }

    result = Payos::ProcessWebhookService.call({
      data: data,
      signature: "invalid_sig"
    })
    assert_equal :bad_request, result[:status]
    assert_equal I18n.t("invoice.payos.webhook.invalid_signature"), result[:json][:error]
    assert @invoice.reload.pending?
  end

  test "processes payment successfully with valid signature" do
    data = {
      "orderCode" => @invoice.payos_order_code,
      "amount" => 4000000,
      "description" => @invoice.payos_transfer_description,
      "accountNumber" => @bank_account.account_number,
      "reference" => "FT_SUCCESS_888",
      "transactionDateTime" => Time.current.strftime("%Y-%m-%d %H:%M:%S")
    }
    signature = PayosService.create_signature(data, @checksum_key)

    result = Payos::ProcessWebhookService.call({
      data: data,
      signature: signature
    })

    assert_equal :ok, result[:status]
    assert_equal true, result[:json][:success]

    @invoice.reload
    assert @invoice.paid?
    assert_equal "transfer", @invoice.payment_method
    assert_equal "PAID", @invoice.payos_status
    assert_includes @invoice.note, "FT_SUCCESS_888"
  end
end
