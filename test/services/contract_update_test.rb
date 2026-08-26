require "test_helper"

class ContractUpdateTest < ActiveSupport::TestCase
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

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @tenant_stay = TenantStay.create!(
      tenant: @tenant,
      rental_unit: @rental_unit,
      checkin_at: Date.current,
      has_contract: true
    )

    @contract = @house.contracts.build(
      tenant: @tenant,
      landlord: @landlord,
      name: "Original Contract",
      landlord_citizen_id: "012345678901",
      tenant_citizen_id: "098765432109",
      start_date: Date.current,
      due_date: Date.current + 6.months,
      deposit_paid: true,
      temp_resid_registered: false,
      note: "Initial note"
    )
    @contract.documents.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "doc1.png",
      content_type: "image/png"
    )
    @contract.save!
  end

  test "updates contract attributes successfully and sends notifications" do
    new_doc = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/normal.png"), "image/png")

    assert_difference -> { @landlord_user.notifications.count }, 1 do
      assert_difference -> { @tenant_user.notifications.count }, 1 do
        ContractUpdate.call(
          house: @house,
          contract: @contract,
          params: {
            name: "Updated Contract Name",
            tenant_citizen_id: "111222333444",
            landlord_citizen_id: "555666777888",
            deposit_paid: false,
            temp_resid_registered: true,
            temp_resid_due_date: Date.current + 3.months,
            note: "Updated note text",
            documents: [ new_doc ]
          }
        )
      end
    end

    @contract.reload
    assert_equal "Updated Contract Name", @contract.name
    assert_equal "111222333444", @contract.tenant_citizen_id
    assert_equal "555666777888", @contract.landlord_citizen_id
    assert_equal false, @contract.deposit_paid
    assert_equal true, @contract.temp_resid_registered
    assert_equal Date.current + 3.months, @contract.temp_resid_due_date
    assert_equal "Updated note text", @contract.note
    assert_equal 2, @contract.documents.count
  end

  test "ignores start_date and due_date from params during update" do
    orig_start = @contract.start_date
    orig_due = @contract.due_date

    ContractUpdate.call(
      house: @house,
      contract: @contract,
      params: {
        name: "Renamed Contract",
        start_date: orig_start - 1.year,
        due_date: orig_due + 2.years
      }
    )

    @contract.reload
    assert_equal orig_start, @contract.start_date
    assert_equal orig_due, @contract.due_date
    assert_equal "Renamed Contract", @contract.name
  end

  test "purges documents when purge_document_ids is provided" do
    doc_id = @contract.documents.first.id

    new_doc = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/normal.png"), "image/png")

    ContractUpdate.call(
      house: @house,
      contract: @contract,
      params: {
        purge_document_ids: [ doc_id ],
        documents: [ new_doc ]
      }
    )

    @contract.reload
    assert_equal 1, @contract.documents.count
    assert_not_equal doc_id, @contract.documents.first.id
  end

  test "clears temp_resid_due_date when temp_resid_registered is set to false" do
    @contract.update!(temp_resid_registered: true, temp_resid_due_date: Date.current + 2.months)

    ContractUpdate.call(
      house: @house,
      contract: @contract,
      params: {
        temp_resid_registered: false
      }
    )

    @contract.reload
    assert_equal false, @contract.temp_resid_registered
    assert_nil @contract.temp_resid_due_date
  end

  test "fails validation if all documents are purged without attaching new ones" do
    doc_id = @contract.documents.first.id

    assert_raises(ActiveRecord::RecordInvalid) do
      ContractUpdate.call(
        house: @house,
        contract: @contract,
        params: {
          purge_document_ids: [ doc_id ]
        }
      )
    end
  end
end
