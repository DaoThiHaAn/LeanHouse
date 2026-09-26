require "test_helper"

class BankAccountTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901118899")
    @bank = Bank.create!(name: "VietinBank", code: "ICB_TEST", bin: "970415", short_name: "VietinBank")
    @bank_account = BankAccount.create!(
      landlord: @landlord_user.landlord,
      bank: @bank,
      account_holder: "NGUYEN VAN A",
      account_number: "102800000002",
      payos_checksum_key: "key_123",
      is_default: true
    )
  end

  test "bank account requires account_number, account_holder, and bank" do
    acc = BankAccount.new
    assert_not acc.valid?
    assert acc.errors[:account_number].present?
    assert acc.errors[:account_holder].present?
  end

  test "setting account as default automatically unsets others" do
    acc2 = BankAccount.create!(
      landlord: @landlord_user.landlord,
      bank: @bank,
      account_holder: "NGUYEN VAN A",
      account_number: "102800000003",
      is_default: false
    )

    acc2.update!(is_default: true)
    assert acc2.reload.is_default?
    assert_not @bank_account.reload.is_default?
  end
end
