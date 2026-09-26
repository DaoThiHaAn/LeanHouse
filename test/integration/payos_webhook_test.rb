require "test_helper"

class PayosWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = create_landlord(tel: "0905555555")
    @landlord = @landlord_user.landlord

    # Create Bank with default values
    @bank = Bank.create!(name: "VietinBank", code: "ICB", bin: "970415", short_name: "VietinBank")
    @bank_account = BankAccount.create!(
      landlord: @landlord,
      bank: @bank,
      account_holder: "NGUYEN VAN A",
      account_number: "102800000001",
      payos_checksum_key: "test_checksum_key_12345",
      is_default: true
    )

    # Create House, Floor, Room
    @house = House.create!(
      landlord: @landlord,
      name: "Nha Tro Mau",
      address_l1: "Phuong Ben Nghe",
      address_l2: "Quan 1",
      address_l3: "TP.HCM",
      mode: :room,
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tang 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Phong 101", area: 25.0, max_slots: 2, tenants_count: 0)

    # Create an Invoice in 'pending' status
    @invoice = @house.invoices.create!(
      room: @room,
      bank_account: @bank_account,
      created_by: @landlord_user,
      code: "INV-#{Time.current.to_i}",
      title: "Tiền phòng T10",
      invoice_type: :room,
      billing_month: Date.current.beginning_of_month,
      due_date: 7.days.from_now.to_date,
      status: "pending",
      subtotal: 3_000_000,
      total_amount: 3_000_000
    )

    @payment_order = PaymentOrder.create!(
      invoice: @invoice,
      order_code: 987654,
      status: "PENDING",
      provider: "payos"
    )
  end

  test "valid PayOS webhook automatically reconciles and marks invoice as paid" do
    webhook_payload = {
      data: {
        orderCode: 987654,
        amount: 3_000_000,
        description: "Thanh toan tien phong",
        accountNumber: @bank_account.account_number,
        reference: "FT2409251234",
        transactionDateTime: Time.current.to_s
      },
      signature: "valid_dummy_signature"
    }

    # Mock signature verification so test runs deterministically in CI/local
    PayosService.stub :verify_webhook_data, true do
      post "/webhooks/payos", params: webhook_payload, as: :json

      assert_response :success
      response_data = JSON.parse(response.body)
      assert response_data["success"]

      # Verify database state changes
      @invoice.reload
      assert_equal "paid", @invoice.status
      assert_not_nil @invoice.paid_at
      assert_equal "transfer", @invoice.payment_method
      assert_includes @invoice.note, "FT2409251234"

      # Verify payment order updated
      @payment_order.reload
      assert_equal "PAID", @payment_order.status
    end
  end

  test "PayOS webhook with invalid signature is rejected with 400 bad request" do
    webhook_payload = {
      data: { orderCode: 987654, amount: 3_000_000 },
      signature: "tampered_or_fake_signature"
    }

    PayosService.stub :verify_webhook_data, false do
      post "/webhooks/payos", params: webhook_payload, as: :json

      assert_response :bad_request
      @invoice.reload
      assert_equal "pending", @invoice.status # Status unchanged
    end
  end

  test "tenant returning from PayOS after successful payment is redirected with success notice" do
    # Log in as landlord/tenant
    post "/login", params: { user: { tel: @landlord_user.tel, password: "Password123", role: "landlord" } }

    PayosService.stub :reconcile_payment!, true do
      get "/payments/payos/return", params: {
        orderCode: @payment_order.order_code,
        status: "PAID",
        code: "00"
      }

      assert_response :redirect
      follow_redirect!
      assert_select ".alert, #flash, div", text: /thành công|hóa đơn/i
    end
  end
end
