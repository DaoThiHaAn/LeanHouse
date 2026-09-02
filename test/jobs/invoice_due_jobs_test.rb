require "test_helper"

class InvoiceDueJobsTest < ActiveJob::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Nguyen",
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
      fullname: "Tenant Le",
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
      name: "Happy House",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @floor = @house.floors.create!(name: "Tầng 1")
    @room = @floor.rooms.create!(
      name: "101",
      floor: @floor,
      max_slots: 2,
      tenants_count: 1,
      area: 25
    )
    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 3000000, deposit: 3000000)

    # Contract & Stay
    @contract = Contract.new(
      landlord: @landlord,
      tenant: @tenant,
      house: @house,
      name: "HĐ Phòng 101",
      start_date: 1.month.ago.to_date,
      due_date: 11.months.from_now.to_date,
      tenant_citizen_id: "012345678901",
      landlord_citizen_id: "098765432109"
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "contract.png",
      content_type: "image/png"
    )
    @contract.save!

    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      has_contract: true,
      checkin_at: 1.month.ago
    )

    # Invoice due today
    @invoice_due_today = Invoice.create!(
      code: "HD2609-101-TODAY",
      title: "Thu tiền tháng 9",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: Date.current.beginning_of_month,
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      due_date: Date.current,
      status: :pending,
      subtotal: 3000000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3000000
    )

    # Invoice overdue 1 day
    @invoice_overdue_1day = Invoice.create!(
      code: "HD2608-101-OVERDUE",
      title: "Thu tiền tháng 8",
      house: @house,
      room: @room,
      created_by: @landlord_user,
      invoice_type: "room",
      billing_month: 1.month.ago.beginning_of_month,
      start_date: 1.month.ago.beginning_of_month,
      end_date: 1.month.ago.end_of_month,
      due_date: 1.day.ago.to_date,
      status: :pending,
      subtotal: 3000000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3000000
    )
  end

  test "InvoiceDueTodayJob delivers notifications to landlord and tenant" do
    assert @invoice_due_today.target_users.include?(@tenant_user)

    assert_nothing_raised do
      InvoiceDueTodayJob.perform_now
    end
  end

  test "InvoiceOverdueCheckJob marks pending invoices overdue and notifies" do
    assert_equal "pending", @invoice_overdue_1day.status

    InvoiceOverdueCheckJob.perform_now

    assert_equal "overdue", @invoice_overdue_1day.reload.status
  end
end
