require "test_helper"

class Invoices::CreateCustomServiceTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Custom Test",
      tel: "0901234567",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Main St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    @tenant_user1 = User.create!(
      fullname: "Tenant One",
      tel: "0901111111",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "Tenant 1 St",
      tel_verified_at: Time.current
    )
    @tenant1 = Tenant.find_or_create_by!(id: @tenant_user1.id)

    @tenant_user2 = User.create!(
      fullname: "Tenant Two",
      tel: "0902222222",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 23.years.ago.to_date,
      address: "Tenant 2 St",
      tel_verified_at: Time.current
    )
    @tenant2 = Tenant.find_or_create_by!(id: @tenant_user2.id)

    @house = House.create!(
      landlord: @landlord,
      name: "Custom Invoice House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 2,
      inv_creation_date: 1
    )

    @floor1 = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @floor2 = @house.floors.create!(name: "Floor 2", position: 2, rooms_count: 1)
    @room1 = @floor1.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 20.0)
    @room2 = @floor2.rooms.create!(name: "Room 201", max_slots: 2, tenants_count: 1, area: 25.0)

    @unit1 = @room1.rental_unit || @room1.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @unit2 = @room2.rental_unit || @room2.create_rental_unit!(rent: 4_000_000, deposit: 4_000_000)

    # Tenant 1 in Room 101, Tenant 2 in Room 201
    @stay1 = @unit1.tenant_stays.create!(tenant: @tenant1, checkin_at: 1.month.ago, checkout_at: nil)
    @stay2 = @unit2.tenant_stays.create!(tenant: @tenant2, checkin_at: 1.month.ago, checkout_at: nil)
  end

  test "successfully creates ad-hoc invoices for arbitrary tenants across different rooms" do
    params = {
      billing_month: Date.current.strftime("%Y-%m"),
      title: "Phí vệ sinh chung tòa nhà",
      due_date: Date.current + 7.days,
      note: "Khoản thu đột xuất",
      tenant_ids: [ @tenant1.id, @tenant2.id ],
      items: {
        "0" => {
          selected: "1",
          item_type: "addition",
          name: "Vệ sinh hành lang",
          unit: "lần",
          unit_price: "100000",
          quantity: "1",
          amount: "100000"
        },
        "1" => {
          selected: "1",
          item_type: "discount",
          name: "Hỗ trợ ban quản lý",
          unit: "lần",
          unit_price: "20000",
          quantity: "1",
          amount: "20000"
        }
      }
    }

    result = nil
    assert_difference -> { Invoice.count } => 2, -> { InvoiceItem.count } => 4 do
      result = Invoices::CreateCustomService.call(
        house: @house,
        landlord: @landlord_user,
        params: params
      )
    end

    assert result.success?
    assert_equal 2, result.invoices.size

    inv1 = result.invoices.find { |i| i.tenant_id == @tenant1.id }
    inv2 = result.invoices.find { |i| i.tenant_id == @tenant2.id }

    assert_not_nil inv1
    assert_not_nil inv2

    # Check Tenant 1 invoice
    assert_equal @room1.id, inv1.room_id
    assert_equal "individual", inv1.invoice_type
    assert_equal "Phí vệ sinh chung tòa nhà", inv1.title
    assert_equal 100_000, inv1.total_addition
    assert_equal 20_000, inv1.total_discount
    assert_equal 80_000, inv1.total_amount
    assert inv1.transfer_note.present?

    # Check Tenant 2 invoice
    assert_equal @room2.id, inv2.room_id
    assert_equal "individual", inv2.invoice_type
    assert_equal "Phí vệ sinh chung tòa nhà", inv2.title
    assert_equal 80_000, inv2.total_amount

    # Ensure unique codes
    assert_not_equal inv1.code, inv2.code
  end

  test "fails when no tenants are selected" do
    params = {
      billing_month: Date.current.strftime("%Y-%m"),
      tenant_ids: [],
      items: {
        "0" => { name: "Fee", unit_price: "50000", quantity: "1" }
      }
    }

    result = Invoices::CreateCustomService.call(
      house: @house,
      landlord: @landlord_user,
      params: params
    )

    assert_not result.success?
    assert_includes result.error_message, "Vui lòng chọn ít nhất một người thuê"
  end

  test "fails when no items are provided" do
    params = {
      billing_month: Date.current.strftime("%Y-%m"),
      tenant_ids: [ @tenant1.id ],
      items: {}
    }

    result = Invoices::CreateCustomService.call(
      house: @house,
      landlord: @landlord_user,
      params: params
    )

    assert_not result.success?
    assert_includes result.error_message, "Vui lòng nhập ít nhất một khoản thu hoặc giảm trừ"
  end

  test "fails when a tenant does not have active stay in the house" do
    other_tenant_user = User.create!(
      fullname: "Other Guy",
      tel: "0909999999",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 25.years.ago.to_date,
      address: "Elsewhere",
      tel_verified_at: Time.current
    )
    other_tenant = Tenant.find_or_create_by!(id: other_tenant_user.id)

    params = {
      billing_month: Date.current.strftime("%Y-%m"),
      tenant_ids: [ @tenant1.id, other_tenant.id ],
      items: {
        "0" => { name: "Fee", unit_price: "50000", quantity: "1" }
      }
    }

    result = Invoices::CreateCustomService.call(
      house: @house,
      landlord: @landlord_user,
      params: params
    )

    assert_not result.success?
    assert_includes result.error_message, "không còn lưu trú"
  end
end
