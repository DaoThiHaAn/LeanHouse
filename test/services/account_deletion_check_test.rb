require "test_helper"

class AccountDeletionCheckTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Test",
      tel: "0901112233",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 35.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user = User.create!(
      fullname: "Tenant Test",
      tel: "0904445566",
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
    @floor = Floor.create!(house: @house, name: "Floor 1", position: 1)
    @room = Room.create!(floor: @floor, name: "Room 101", max_slots: 2, tenants_count: 0, area: 25.0)
  end

  test "unlinked tenant with no pending debts or requests can delete account" do
    result = AccountDeletionCheck.call(@tenant_user)

    assert result.can_delete?
    assert_empty result.blockers
  end

  test "tenant actively linked to a stay cannot delete account" do
    rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    TenantStay.create!(
      tenant: @tenant,
      rental_unit: rental_unit,
      checkin_at: 1.month.ago
    )

    result = AccountDeletionCheck.call(@tenant_user)

    assert_not result.can_delete?
    assert_equal 1, result.blockers.size
    assert_equal :active_stay, result.blockers.first.key
  end

  test "tenant with unpaid invoice cannot delete account" do
    Invoice.create!(
      code: "INV-DEL-TEST-1",
      house: @house,
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      title: "Rent Month 1",
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      invoice_type: :room,
      subtotal: 3_000_000,
      total_amount: 3_000_000
    )

    result = AccountDeletionCheck.call(@tenant_user)

    assert_not result.can_delete?
    assert result.blockers.any? { |b| b.key == :unpaid_invoices }
  end

  test "landlord with empty houses and no debts can delete account" do
    result = AccountDeletionCheck.call(@landlord_user)

    assert result.can_delete?
    assert_empty result.blockers
  end

  test "landlord with active tenants cannot delete account" do
    @room.update!(tenants_count: 1)

    result = AccountDeletionCheck.call(@landlord_user)

    assert_not result.can_delete?
    active_tenants_blocker = result.blockers.find { |b| b.key == :active_tenants }
    assert_not_nil active_tenants_blocker
    assert_equal 1, active_tenants_blocker.count
  end

  test "landlord with unpaid house invoices cannot delete account" do
    Invoice.create!(
      code: "INV-DEL-TEST-2",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      title: "Electricity Month 1",
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      status: :pending,
      invoice_type: :room,
      subtotal: 500_000,
      total_amount: 500_000
    )

    result = AccountDeletionCheck.call(@landlord_user)

    assert_not result.can_delete?
    assert result.blockers.any? { |b| b.key == :unpaid_invoices }
  end
end
