require "test_helper"

class ContractTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Tran",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Pham",
      tel: "0907654321",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Tenant Rd",
      tel_verified_at: Time.current
    )
    @tenant = Tenant.find_or_create_by!(id: @tenant_user.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Sunrise House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Tầng 1")
    @room = @floor.rooms.create!(name: "101", floor: @floor, max_slots: 2, tenants_count: 1, area: 25)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      has_contract: true,
      checkin_at: 1.year.ago
    )
  end

  test "auto_close_if_overdue! closes contract when due_date < reference_date and unlinks stay" do
    contract = create_contract(start_date: 1.year.ago.to_date, due_date: 2.months.ago.to_date)
    assert_nil contract.end_date
    assert @tenant_stay.reload.has_contract?

    result = contract.auto_close_if_overdue!(Date.current, send_noti: false)
    assert result
    assert_equal 2.months.ago.to_date, contract.reload.end_date
    assert_not @tenant_stay.reload.has_contract?
    assert_equal :finished, contract.due_status
  end

  test "auto_close_if_overdue! skips when contract is not overdue" do
    contract = create_contract(start_date: 1.month.ago.to_date, due_date: 6.months.from_now.to_date)
    result = contract.auto_close_if_overdue!(Date.current, send_noti: false)
    assert_not result
    assert_nil contract.reload.end_date
    assert @tenant_stay.reload.has_contract?
  end

  test "auto_close_if_overdue! skips when contract is already finished" do
    contract = create_contract(start_date: 1.year.ago.to_date, due_date: 2.months.ago.to_date)
    contract.update!(end_date: 2.months.ago.to_date)

    result = contract.auto_close_if_overdue!(Date.current, send_noti: false)
    assert_not result
  end

  test "ContractSigning auto-closes contract when created with past due_date" do
    contract_params = {
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      name: "HD-Past-101",
      start_date: Date.new(2024, 3, 1),
      due_date: Date.new(2024, 12, 31),
      temp_resid_registered: false,
      documents: [
        { io: File.open(Rails.root.join("test/fixtures/files/normal.png")), filename: "c1.png", content_type: "image/png" }
      ]
    }

    signed_contract = ContractSigning.call(
      house: @house,
      tenant_stay: @tenant_stay,
      landlord: @landlord,
      params: contract_params,
      send_noti: false
    )

    assert signed_contract.persisted?
    assert_equal Date.new(2024, 12, 31), signed_contract.reload.end_date
    assert signed_contract.finished?
    assert_not @tenant_stay.reload.has_contract?
  end

  test "ContractSigning leaves active contract with has_contract true when created with future due_date" do
    contract_params = {
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      name: "HD-Future-101",
      start_date: Date.current,
      due_date: Date.current + 6.months,
      temp_resid_registered: false,
      documents: [
        { io: File.open(Rails.root.join("test/fixtures/files/normal.png")), filename: "c1.png", content_type: "image/png" }
      ]
    }

    signed_contract = ContractSigning.call(
      house: @house,
      tenant_stay: @tenant_stay,
      landlord: @landlord,
      params: contract_params,
      send_noti: false
    )

    assert signed_contract.persisted?
    assert_nil signed_contract.reload.end_date
    assert_not signed_contract.finished?
    assert @tenant_stay.reload.has_contract?
  end

  test "ContractRenewal auto-closes contract when renewed with past due_date" do
    old_contract = create_contract(start_date: 2.years.ago.to_date, due_date: 1.year.ago.to_date)
    renewal_params = {
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      name: "HD-Renewed-Past",
      start_date: 1.year.ago.to_date,
      due_date: 6.months.ago.to_date,
      temp_resid_registered: false,
      documents: [
        { io: File.open(Rails.root.join("test/fixtures/files/normal.png")), filename: "c2.png", content_type: "image/png" }
      ]
    }

    renewed = ContractRenewal.call(
      house: @house,
      old_contract: old_contract,
      tenant_stay: @tenant_stay,
      landlord: @landlord,
      params: renewal_params,
      send_noti: false
    )

    assert renewed.persisted?
    assert_equal 6.months.ago.to_date, renewed.reload.end_date
    assert renewed.finished?
    assert_not @tenant_stay.reload.has_contract?
  end

  test "Invoices::IssueService auto-closes overdue contract for the room when invoice is issued" do
    contract = create_contract(start_date: 1.year.ago.to_date, due_date: 2.months.ago.to_date)
    assert_nil contract.end_date
    assert @tenant_stay.reload.has_contract?

    invoice_params = {
      title: "Hóa đơn kỳ trước",
      items: [
        { selected: "1", item_type: "rent", name: "Tiền phòng", unit_price: 3_000_000, quantity: 1, amount: 3_000_000 }
      ]
    }

    Invoices::IssueService.call(
      room: @room,
      billing_month: 2.months.ago.beginning_of_month,
      landlord: @landlord_user,
      params: invoice_params
    )

    assert_equal 2.months.ago.to_date, contract.reload.end_date
    assert contract.finished?
    assert_not @tenant_stay.reload.has_contract?
  end

  test "Invoices::CreateCustomService auto-closes overdue contract for selected tenant when custom invoice is issued" do
    contract = create_contract(start_date: 1.year.ago.to_date, due_date: 2.months.ago.to_date)
    assert_nil contract.end_date
    assert @tenant_stay.reload.has_contract?

    custom_params = {
      tenant_ids: [ @tenant.id ],
      billing_month: 2.months.ago.beginning_of_month.strftime("%Y-%m"),
      title: "Hóa đơn dịch vụ cũ",
      items: [
        { selected: "1", item_type: "addition", name: "Phí bổ sung", unit_price: 200_000, quantity: 1, amount: 200_000 }
      ]
    }

    result = Invoices::CreateCustomService.call(
      house: @house,
      landlord: @landlord_user,
      params: custom_params
    )

    assert result.success?
    assert_equal 2.months.ago.to_date, contract.reload.end_date
    assert contract.finished?
    assert_not @tenant_stay.reload.has_contract?
  end

  private

  def create_contract(start_date:, due_date:)
    contract = @house.contracts.build(
      landlord: @landlord,
      tenant: @tenant,
      name: "Hợp đồng kiểm thử",
      start_date: start_date,
      due_date: due_date,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      deposit_paid: true
    )
    contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "contract.png",
      content_type: "image/png"
    )
    contract.save!
    contract
  end
end

