require "test_helper"

class ContractClosingTest < ActiveSupport::TestCase
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

  test "ContractClosing.call closes contract and unlinks stay without removing tenant" do
    contract = create_contract(start_date: 1.month.ago.to_date, due_date: 6.months.from_now.to_date)
    assert_nil contract.end_date
    assert @tenant_stay.reload.has_contract?

    ContractClosing.call(house: @house, contract: contract, remove_tenant: false)

    assert_equal Date.current, contract.reload.end_date
    assert_not @tenant_stay.reload.has_contract?
    assert_nil @tenant_stay.checkout_at
  end

  test "ContractClosing.close_if_overdue! auto-closes contract when due_date < reference_date" do
    contract = create_contract(start_date: 1.year.ago.to_date, due_date: 2.months.ago.to_date)
    assert_nil contract.end_date

    result = ContractClosing.close_if_overdue!(contract, Date.current, send_noti: false)
    assert result
    assert_equal 2.months.ago.to_date, contract.reload.end_date
    assert_not @tenant_stay.reload.has_contract?
    assert_equal :finished, contract.due_status
  end

  test "ContractClosing.close_if_overdue! skips non-overdue or already finished contract" do
    contract = create_contract(start_date: 1.month.ago.to_date, due_date: 6.months.from_now.to_date)
    assert_not ContractClosing.close_if_overdue!(contract, Date.current)

    contract.update!(end_date: Date.current)
    assert_not ContractClosing.close_if_overdue!(contract, Date.current)
  end

  test "ContractClosing.close_overdue! batch closes overdue unfinished contracts" do
    overdue_contract = create_contract(start_date: 1.year.ago.to_date, due_date: 1.month.ago.to_date)
    active_contract = @house.contracts.build(
      landlord: @landlord,
      tenant: @tenant,
      name: "HD Active",
      start_date: Date.current,
      due_date: 6.months.from_now.to_date,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109",
      deposit_paid: true
    )
    active_contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "contract.png",
      content_type: "image/png"
    )
    active_contract.save!

    ContractClosing.close_overdue!(Contract.where(id: [ overdue_contract.id, active_contract.id ]), send_noti: false)

    assert_equal 1.month.ago.to_date, overdue_contract.reload.end_date
    assert overdue_contract.finished?
    assert_nil active_contract.reload.end_date
    assert_not active_contract.finished?
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

