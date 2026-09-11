require "test_helper"

class BankAccountTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      fullname: "Bank Model Test User",
      tel: "0922334455",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "Hanoi",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
    @mb_bank = Bank.create!(name: "Military Bank", code: "MB", bin: "970422", short_name: "MB")
    @vcb_bank = Bank.create!(name: "Vietcombank", code: "VCB", bin: "970436", short_name: "VCB")
  end

  test "payos_supported_bank? detects supported banks" do
    mb_acc = @landlord.bank_accounts.build(bank: @mb_bank, account_number: "0922334455", account_holder: "TEST USER")
    assert mb_acc.payos_supported_bank?

    vcb_acc = @landlord.bank_accounts.build(bank: @vcb_bank, account_number: "0011009988", account_holder: "TEST USER")
    assert_not vcb_acc.payos_supported_bank?
  end

  test "validates presence of keys and supported bank when payos_enabled is true" do
    acc = @landlord.bank_accounts.build(
      bank: @vcb_bank,
      account_number: "0011009988",
      account_holder: "TEST USER",
      payos_enabled: true
    )
    assert_not acc.valid?
    assert acc.errors[:payos_client_id].present?
    assert acc.errors[:payos_api_key].present?
    assert acc.errors[:payos_checksum_key].present?
    assert acc.errors[:base].any? { |e| e.include?("chưa được hỗ trợ") }

    # When switching to supported bank and providing keys
    acc.bank = @mb_bank
    acc.payos_client_id = "client-123"
    acc.payos_api_key = "api-123"
    acc.payos_checksum_key = "checksum-123"
    assert acc.valid?
    assert acc.payos_configured?
  end
end
