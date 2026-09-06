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

  test "landlord can add a new bank account with consent via HTML" do
    sign_in_as(@landlord_user)

    assert_difference -> { @landlord.bank_accounts.count }, 1 do
      post landlord_bank_accounts_url, params: {
        bank_account: {
          bank_id: @bank.id,
          account_number: "9988776655",
          account_holder: "CHU TRO 2",
          is_default: "0",
          consent_accepted: "1"
        }
      }
    end

    assert_redirected_to landlord_bank_accounts_url
    follow_redirect!
    assert_includes response.body, I18n.t("bank_account.created_success")
  end

  test "cannot add a new bank account if consent is not accepted" do
    sign_in_as(@landlord_user)

    assert_no_difference -> { @landlord.bank_accounts.count } do
      post landlord_bank_accounts_url, params: {
        bank_account: {
          bank_id: @bank.id,
          account_number: "9988776655",
          account_holder: "CHU TRO 2",
          is_default: "0",
          consent_accepted: "0"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not_includes response.body, "translation missing"
  end

  test "landlord can add a new bank account via Turbo Stream" do
    sign_in_as(@landlord_user)

    assert_difference -> { @landlord.bank_accounts.count }, 1 do
      post landlord_bank_accounts_url, as: :turbo_stream, params: {
        bank_account: {
          bank_id: @bank.id,
          account_number: "8877665544",
          account_holder: "CHU TRO TURBO",
          is_default: "0",
          consent_accepted: "1"
        }
      }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(turbo-stream action="update" target="flash")
    assert_includes response.body, %(turbo-stream action="update" target="bank_accounts_count")
    assert_includes response.body, %(turbo-stream action="update" target="bank_accounts_list_container")
    assert_includes response.body, %(turbo-stream action="update" target="bank_account_form_container")
    assert_includes response.body, "8877665544"
    assert_includes response.body, I18n.t("bank_account.created_success")
  end

  test "duplicate bank account is rejected with localized error message and no translation missing" do
    sign_in_as(@landlord_user)

    assert_no_difference -> { @landlord.bank_accounts.count } do
      post landlord_bank_accounts_url, as: :turbo_stream, params: {
        bank_account: {
          bank_id: @bank.id,
          account_number: @bank_account.account_number,
          account_holder: "ANOTHER HOLDER",
          consent_accepted: "1"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_not_includes response.body, "translation missing"
    assert_includes response.body, I18n.t("activerecord.errors.models.bank_account.attributes.account_number.already_added")
  end

  test "landlord can get edit view for bank account" do
    sign_in_as(@landlord_user)
    get edit_landlord_bank_account_url(@bank_account)
    assert_response :success
    assert_includes response.body, %(turbo-frame id="bank_account_#{@bank_account.id}")
    assert_includes response.body, I18n.t("bank_account.edit_title")
  end

  test "landlord can update bank account via HTML and Turbo Stream" do
    sign_in_as(@landlord_user)

    # HTML update
    patch landlord_bank_account_url(@bank_account), params: {
      bank_account: {
        account_holder: "CHU TRO UPDATED"
      }
    }
    assert_redirected_to landlord_bank_accounts_url
    assert_equal "CHU TRO UPDATED", @bank_account.reload.account_holder

    # Turbo Stream update
    patch landlord_bank_account_url(@bank_account), as: :turbo_stream, params: {
      bank_account: {
        account_holder: "CHU TRO TURBO UPDATED"
      }
    }
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(turbo-stream action="update" target="bank_accounts_list_container")
    assert_includes response.body, "CHU TRO TURBO UPDATED"
    assert_equal "CHU TRO TURBO UPDATED", @bank_account.reload.account_holder
  end

  test "landlord can set bank account as default via Turbo Stream and CSS default class moves to new default" do
    acc2 = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "1122334455",
      account_holder: "CHU TRO NEW",
      is_default: false
    )

    sign_in_as(@landlord_user)
    patch set_default_landlord_bank_account_url(acc2), as: :turbo_stream
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(turbo-stream action="update" target="flash")
    assert_includes response.body, %(turbo-stream action="update" target="bank_accounts_list_container")
    assert acc2.reload.is_default?
    assert_not @bank_account.reload.is_default?

    # Verify that acc2 has the "default" class and old @bank_account does NOT
    assert_includes response.body, %(id="bank_account_col_#{acc2.id}")
    assert_includes response.body, %(id="bank_account_col_#{@bank_account.id}")

    # Parse response to ensure default badge and class are only on the new default
    assert_select "div#bank_account_col_#{acc2.id} .bank.card.default", count: 1
    assert_select "div#bank_account_col_#{@bank_account.id} .bank.card.default", count: 0
  end

  test "cannot delete bank account when it has unpaid invoices" do
    house = House.create!(
      landlord: @landlord,
      name: "House Bank Test",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = house.floors.create!(name: "Tầng 1")
    room = floor.rooms.create!(name: "101", max_slots: 2, tenants_count: 0, area: 25)

    invoice = Invoice.create!(
      code: "HD-TEST-UNPAID",
      title: "Hóa đơn thử nghiệm",
      house: house,
      room: room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      subtotal: 2000000,
      total_amount: 2000000,
      bank_account: @bank_account
    )

    sign_in_as(@landlord_user)

    assert_no_difference -> { @landlord.bank_accounts.count } do
      delete landlord_bank_account_url(@bank_account), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("bank_account.cannot_delete_has_pending_invoices")
  end

  test "landlord can delete bank account via Turbo Stream and remaining account becomes default" do
    acc2 = @landlord.bank_accounts.create!(
      bank: @bank,
      account_number: "5544332211",
      account_holder: "CHU TRO REMAINING",
      is_default: false
    )

    sign_in_as(@landlord_user)

    assert_difference -> { @landlord.bank_accounts.count }, -1 do
      delete landlord_bank_account_url(@bank_account), as: :turbo_stream
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, %(turbo-stream action="update" target="bank_accounts_list_container")
    assert_includes response.body, I18n.t("bank_account.deleted_success")
    assert acc2.reload.is_default?, "Remaining account should be promoted to default"
  end
end
