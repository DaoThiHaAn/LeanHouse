require "test_helper"

class ContractJobsTest < ActiveJob::TestCase
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
      checkin_at: 1.month.ago
    )
  end

  test "ContractOverdueCloseJob closes overdue contract and unlinks stay" do
    contract = create_contract(start_date: 6.months.ago.to_date, due_date: 1.day.ago.to_date)

    assert_nil contract.end_date
    assert @tenant_stay.reload.has_contract?

    assert_enqueued_with(job: Noticed::EventJob) do
      ContractOverdueCloseJob.perform_now
    end

    assert_equal 1.day.ago.to_date, contract.reload.end_date
    assert_not @tenant_stay.reload.has_contract?
  end

  test "ContractOverdueCloseJob skips closing if contract was concurrently extended" do
    contract = create_contract(start_date: 6.months.ago.to_date, due_date: 1.day.ago.to_date)

    # Concurrently extend the contract right before execution
    contract.update!(due_date: 3.months.from_now.to_date)

    assert_no_enqueued_jobs(only: Noticed::EventJob) do
      ContractOverdueCloseJob.perform_now
    end

    assert_nil contract.reload.end_date
    assert @tenant_stay.reload.has_contract?
  end

  test "ContractDueReminderJob skips if contract was concurrently extended beyond target date" do
    contract = create_contract(start_date: 1.month.ago.to_date, due_date: Date.current + 30.days)
    contract.update!(due_date: Date.current + 60.days)

    assert_no_enqueued_jobs(only: Noticed::EventJob) do
      ContractDueReminderJob.perform_now
    end
  end

  test "ContractDueTodayJob skips if contract was concurrently extended" do
    contract = create_contract(start_date: 1.month.ago.to_date, due_date: Date.current)
    contract.update!(due_date: Date.current + 1.month)

    assert_no_enqueued_jobs(only: Noticed::EventJob) do
      ContractDueTodayJob.perform_now
    end
  end

  private

  def create_contract(start_date:, due_date:)
    contract = @house.contracts.build(
      landlord: @landlord,
      tenant: @tenant,
      name: "Hợp đồng thuê 101",
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
