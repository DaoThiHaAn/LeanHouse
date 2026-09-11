require "test_helper"

class PayosServiceTest < ActiveSupport::TestCase
  def setup
    @checksum_key = "test_checksum_key_12345"
  end

  test "create_signature sorts keys alphabetically and generates HMAC-SHA256" do
    data = {
      "cancelUrl" => "https://example.com/cancel",
      "amount" => 150000,
      "returnUrl" => "https://example.com/return",
      "orderCode" => 12345,
      "description" => "Test transfer"
    }

    # Sorted order: amount, cancelUrl, description, orderCode, returnUrl
    expected_data_str = "amount=150000&cancelUrl=https://example.com/cancel&description=Test transfer&orderCode=12345&returnUrl=https://example.com/return"
    expected_sig = OpenSSL::HMAC.hexdigest("SHA256", @checksum_key, expected_data_str)

    computed_sig = PayosService.create_signature(data, @checksum_key)
    assert_equal expected_sig, computed_sig
  end

  test "verify_webhook_data returns true for valid signature and false for tampered data" do
    webhook_data = {
      "orderCode" => 987654321,
      "amount" => 2500000,
      "description" => "HD 987654321",
      "accountNumber" => "12345678",
      "reference" => "FT26090123"
    }

    valid_sig = PayosService.create_signature(webhook_data, @checksum_key)

    assert PayosService.verify_webhook_data(webhook_data, valid_sig, @checksum_key)

    tampered_data = webhook_data.merge("amount" => 1000000)
    assert_not PayosService.verify_webhook_data(tampered_data, valid_sig, @checksum_key)

    assert_not PayosService.verify_webhook_data(webhook_data, "fake_signature", @checksum_key)
  end

  test "create_payment_link returns error when bank account is not configured" do
    user = User.create!(
      fullname: "Landlord Test",
      tel: "0988776655",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "Hanoi",
      tel_verified_at: Time.current
    )
    landlord = Landlord.find_or_create_by!(id: user.id)
    bank = Bank.create!(name: "Vietcombank", code: "VCB", bin: "970436", short_name: "VCB")
    bank_account = landlord.bank_accounts.create!(
      bank: bank,
      account_number: "0011009999",
      account_holder: "TEST USER"
    )
    house = House.create!(
      landlord: landlord,
      name: "Test House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 20.0)
    invoice = house.invoices.create!(
      room: room,
      created_by: user,
      bank_account: bank_account,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      title: "Tiền phòng",
      subtotal: 3000000,
      total_amount: 3000000,
      status: "pending",
      code: "HD-TEST-123"
    )

    result = PayosService.create_payment_link(invoice)
    assert_equal false, result[:success]
    assert_includes result[:error], "not configured"
  end

  test "webhook_url prioritizes PAYOS_WEBHOOK_URL environment variable" do
    original_val = ENV["PAYOS_WEBHOOK_URL"]
    begin
      ENV["PAYOS_WEBHOOK_URL"] = "https://custom.webhook.url/test"
      mock_request = Struct.new(:base_url).new("https://request.host.com")
      assert_equal "https://custom.webhook.url/test", PayosService.webhook_url(mock_request)
    ensure
      ENV["PAYOS_WEBHOOK_URL"] = original_val
    end
  end

  test "webhook_url uses request base_url when provided" do
    original_val = ENV["PAYOS_WEBHOOK_URL"]
    begin
      ENV["PAYOS_WEBHOOK_URL"] = nil
      mock_request = Struct.new(:base_url).new("https://tenant.leanhouse.vn")
      assert_equal "https://tenant.leanhouse.vn/webhooks/payos", PayosService.webhook_url(mock_request)
    ensure
      ENV["PAYOS_WEBHOOK_URL"] = original_val
    end
  end

  test "webhook_url uses APP_HOST when request is nil" do
    original_webhook = ENV["PAYOS_WEBHOOK_URL"]
    original_host = ENV["APP_HOST"]
    begin
      ENV["PAYOS_WEBHOOK_URL"] = nil
      ENV["APP_HOST"] = "production.leanhouse.vn"
      url = PayosService.webhook_url(nil)
      assert_includes url, "production.leanhouse.vn/webhooks/payos"
    ensure
      ENV["PAYOS_WEBHOOK_URL"] = original_webhook
      ENV["APP_HOST"] = original_host
    end
  end
end
