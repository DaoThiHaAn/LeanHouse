# frozen_string_literal: true

require "application_system_test_case"

class ContractsAndTenantsTest < ApplicationSystemTestCase
  setup do
    @landlord_user = create_landlord(tel: "0908123123", password: "Password123")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Hợp Đồng",
      mode: :room,
      address_l1: "50 Trần Hưng Đạo",
      address_l2: "Phường Phạm Ngũ Lão",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P.401", area: 26.0, max_slots: 2, tenants_count: 1)

    @tenant_user = create_tenant(tel: "0909123123", password: "Password123", fullname: "Hoang Thi Chua Ky HD")
    @tenant = @tenant_user.tenant

    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 4_000_000, deposit: 4_000_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.week.ago,
      checkout_at: nil
    )
  end

  test "landlord contracts page displays unsigned tenant warning and toggles collapsible sidebar via Stimulus" do
    sign_in_as(@landlord_user)
    visit landlord_house_contracts_path(@house)

    assert_selector "[data-controller='collapsible']", wait: 5
    assert_selector "[data-collapsible-target='expanded']:not(.d-none)"
    assert_selector "a[href='#{new_landlord_house_tenant_contract_path(@house, @tenant)}']"

    # Click collapse button to trigger Stimulus collapsible#toggle
    find("[data-collapsible-target='expanded'] [data-action='click->collapsible#toggle']").click
    assert_selector "[data-collapsible-target='collapsed']:not(.d-none)", wait: 5

    # Click collapsed bar to expand again
    find("[data-collapsible-target='collapsed']").click
    assert_selector "[data-collapsible-target='expanded']:not(.d-none)", wait: 5
  end
end
