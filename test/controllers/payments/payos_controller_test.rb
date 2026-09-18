# frozen_string_literal: true

require "test_helper"

class Payments::PayosControllerTest < ActionDispatch::IntegrationTest
  def setup
    @landlord_user = User.create!(
      fullname: "Landlord Return Test",
      tel: "0911223344",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "Hanoi",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @bank = Bank.find_or_create_by!(bin: "970422") do |b|
      b.name = "Military Commercial Joint Stock Bank"
      b.code = "MB"
      b.short_name = "MBBank"
    end
    @bank_account = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "0011009988",
      account_holder: "LANDLORD TEST",
      payos_enabled: true,
      payos_client_id: "test-client-id",
      payos_api_key: "test-api-key",
      payos_checksum_key: "test-checksum-key"
    )

    @house = House.create!(
      landlord: @landlord,
      name: "PayOS Return House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 20.0)

    @tenant_user = User.create!(
      fullname: "Tenant Return Test",
      tel: "0922334455",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "Hanoi",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )

    @invoice = @house.invoices.create!(
      code: "HD-PAYOS-RET-1",
      title: "Tiền phòng tháng này",
      room: @room,
      created_by: @landlord_user,
      bank_account: @bank_account,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 3_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_000_000
    )

    @payment_order = @invoice.payment_orders.create!(
      provider: "payos",
      order_code: 888777666,
      payment_link_id: "link_ret_123",
      checkout_url: "https://pay.payos.vn/web/link_ret_123",
      status: "PENDING"
    )
  end

  test "unauthenticated user return renders public receipt page without redirecting to login" do
    get payments_payos_return_url(
      @invoice.id,
      code: "00",
      status: "PAID",
      orderCode: @payment_order.order_code
    )

    assert_response :success
    refute_equal login_path, response.location
    assert_includes response.body, I18n.t("invoice.payos.result.title_success")
    assert_includes response.body, @invoice.code
    assert_includes response.body, I18n.t("invoice.payos.result.login_btn")
  end

  test "unauthenticated user cancel renders cancelled public receipt" do
    get payments_payos_cancel_url(
      @invoice.id,
      cancel: "true",
      status: "CANCELLED",
      orderCode: @payment_order.order_code
    )

    assert_response :success
    assert_includes response.body, I18n.t("invoice.payos.result.title_cancelled")
    assert_includes response.body, @invoice.code
  end

  test "authenticated tenant return redirects to tenant invoice show with notice" do
    sign_in_as(@tenant_user)

    get payments_payos_return_url(
      @invoice.id,
      code: "00",
      status: "PAID",
      orderCode: @payment_order.order_code
    )

    assert_redirected_to tenant_invoice_path(@invoice)
    follow_redirect!
    assert_response :success
    assert_equal I18n.t("invoice.payos.payment_success_flash"), flash[:notice]
  end

  test "authenticated landlord return redirects to landlord house invoice show with notice" do
    sign_in_as(@landlord_user)

    get payments_payos_return_url(
      @invoice.id,
      code: "00",
      status: "PAID",
      orderCode: @payment_order.order_code
    )

    assert_redirected_to landlord_house_invoice_path(@house, @invoice)
    follow_redirect!
    assert_response :success
    assert_equal I18n.t("invoice.payos.payment_success_flash"), flash[:notice]
  end

  test "unauthenticated access to tenant invoice with payos params redirects to payments return" do
    get tenant_invoice_url(
      @invoice.id,
      code: "00",
      status: "PAID",
      orderCode: @payment_order.order_code
    )

    assert_response :redirect
    assert_includes response.location, "/payments/payos/return"
    refute_equal login_url, response.location
  end

  private

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end
end
