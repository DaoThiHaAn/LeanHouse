# frozen_string_literal: true

require "test_helper"

class ContractDueTodayNotifierTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901114455")
    @tenant_user = create_tenant(tel: "0902224455")

    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Contract Noti House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    @contract = Contract.new(
      house: @house,
      landlord: @landlord_user.landlord,
      tenant: @tenant_user.tenant,
      name: "HD-001",
      landlord_citizen_id: "079199000001",
      tenant_citizen_id: "079201000002",
      start_date: 6.months.ago.to_date,
      due_date: Date.current
    )
    @contract.documents.attach(
      io: StringIO.new("contract image"),
      filename: "contract.jpg",
      content_type: "image/jpeg"
    )
    @contract.save!
  end

  test "delivers notification to landlord and tenant with formatted messages" do
    ContractDueTodayNotifier.with(
      contract: @contract,
      contract_id: @contract.id,
      house_id: @house.id,
      contract_name: @contract.name,
      tenant_name: @tenant_user.fullname,
      due_date: Date.current.strftime("%d/%m/%Y")
    ).deliver([ @landlord_user, @tenant_user ])

    landlord_noti = @landlord_user.notifications.last
    assert_not_nil landlord_noti
    assert_includes landlord_noti.url, "/landlord/houses/#{@house.id}/contracts/#{@contract.id}"

    tenant_noti = @tenant_user.notifications.last
    assert_not_nil tenant_noti
    assert_includes tenant_noti.url, "/tenant/contract"
  end
end
