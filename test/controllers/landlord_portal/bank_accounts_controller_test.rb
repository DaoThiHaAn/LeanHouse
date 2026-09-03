require "test_helper"

class LandlordPortal::BankAccountsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @landlord_user = User.create!(
      fullname: "Chủ Trọ Bank Test",
      tel: "0911223344",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Le Loi, Q1",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @bank = Bank.create!(
      name: "Ngân hàng Ngoại thương Việt Nam",
      code: "VCB",
      bin: "970436",
      short_name: "Vietcombank",
      logo_url: "https://api.vietqr.io/img/VCB.png"
    )

    @bank_account = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "0011001234567",
      account_holder: "CHU TRO BANK TEST",
      is_default: true
    )
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "unauthenticated user cannot access landlord bank accounts index" do
    get landlord_bank_accounts_url
    assert_redirected_to login_url
  end

  test "landlord can view bank accounts index without duplicate flashes or missing translations" do
    sign_in_as(@landlord_user)
    get landlord_bank_accounts_url
    assert_response :success
    assert_includes response.body, "Vietcombank"
    assert_includes response.body, "0011001234567"
    assert_includes response.body, "CHU TRO BANK TEST"
    assert_select "img[src*='VCB.png']"
    assert_select ".bank-account-card-logo"
    assert_not_includes response.body, "translation missing"
  end

  test "landlord can add a new bank account" do
    sign_in_as(@landlord_user)

    assert_difference -> { @landlord.bank_accounts.count }, 1 do
      post landlord_bank_accounts_url, params: {
        bank_account: {
          bank_id: @bank.id,
          account_number: "9988776655",
          account_holder: "CHU TRO 2",
          is_default: "0"
        }
      }
    end

    assert_redirected_to landlord_bank_accounts_url
    follow_redirect!
    assert_includes response.body, I18n.t("bank_account.created_success")
  end

  test "landlord can set bank account as default" do
    acc2 = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "1122334455",
      account_holder: "CHU TRO NEW",
      is_default: false
    )

    sign_in_as(@landlord_user)
    patch set_default_landlord_bank_account_url(acc2)
    assert_redirected_to landlord_bank_accounts_url
    follow_redirect!
    assert_includes response.body, I18n.t("bank_account.set_default_success")
    assert acc2.reload.is_default?
  end

  test "landlord can delete bank account" do
    sign_in_as(@landlord_user)

    assert_difference -> { @landlord.bank_accounts.count }, -1 do
      delete landlord_bank_account_url(@bank_account)
    end

    assert_redirected_to landlord_bank_accounts_url
    follow_redirect!
    assert_includes response.body, I18n.t("bank_account.deleted_success")
  end
end
