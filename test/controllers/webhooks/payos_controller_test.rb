require "test_helper"

class Webhooks::PayosControllerTest < ActionDispatch::IntegrationTest
  def setup
    @checksum_key = "secret_checksum_test_key"
    @user = User.create!(
      fullname: "Webhook Test User",
      tel: "0911554433",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "Hanoi",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
    @bank = Bank.create!(name: "Military Commercial Joint Stock Bank", code: "MB", bin: "970422", short_name: "MBBank")
    @bank_account = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "0911554433",
      account_holder: "WEBHOOK TEST USER",
      payos_enabled: true,
      payos_client_id: "client-id-123",
      payos_api_key: "api-key-123",
      payos_checksum_key: @checksum_key
    )

    @house = House.create!(
      landlord: @landlord,
      name: "Webhook Test House",
      mode: :room,
      address_l1: "456 Street",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "201", max_slots: 2, tenants_count: 0, area: 22.0)
    @invoice = @house.invoices.create!(
      room: @room,
      created_by: @user,
      bank_account: @bank_account,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      title: "Tiền phòng T9",
      subtotal: 3500000,
      total_amount: 3500000,
      status: "pending",
      code: "HD-PAYOS-TEST-001"
    )
  end

  test "receive handles empty or test ping payload from payOS dashboard" do
    post webhooks_payos_url, params: {}, as: :json
    assert_response :success

    post webhooks_payos_url, params: { data: {} }, as: :json
    assert_response :success
  end

  test "receive successfully marks invoice as paid when valid signature provided" do
    data = {
      "orderCode" => @invoice.payos_order_code,
      "amount" => 3500000,
      "description" => @invoice.payos_transfer_description,
      "accountNumber" => @bank_account.account_number,
      "reference" => "FT2609099999",
      "transactionDateTime" => Time.current.strftime("%Y-%m-%d %H:%M:%S")
    }
    signature = PayosService.create_signature(data, @checksum_key)

    assert_enqueued_with(job: LandlordDashboardBroadcastJob, args: [ @house.id ]) do
      post webhooks_payos_url, params: {
        code: "00",
        desc: "success",
        data: data,
        signature: signature
      }, as: :json
    end

    assert_response :success
    @invoice.reload
    assert @invoice.paid?
    assert_equal "transfer", @invoice.payment_method
    assert_equal "PAID", @invoice.payos_status
    assert_includes @invoice.note, "FT2609099999"
  end

  test "receive rejects webhook when signature is invalid" do
    data = {
      "orderCode" => @invoice.payos_order_code,
      "amount" => 3500000,
      "description" => @invoice.payos_transfer_description,
      "reference" => "FT_FAKE_123"
    }

    post webhooks_payos_url, params: {
      code: "00",
      desc: "success",
      data: data,
      signature: "tampered_signature"
    }, as: :json

    assert_response :bad_request
    @invoice.reload
    assert @invoice.pending?
  end

  test "receive gracefully handles unknown orderCode" do
    data = {
      "orderCode" => 999999999,
      "amount" => 1000000
    }

    post webhooks_payos_url, params: {
      code: "00",
      data: data
    }, as: :json

    assert_response :success
  end
end
