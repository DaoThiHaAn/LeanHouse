# frozen_string_literal: true

require "test_helper"

class TenantLinkFormTest < ActiveSupport::TestCase
  setup do
    @landlord_user = User.create!(
      fullname: "Landlord Form Test",
      tel: "090#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Landlord St",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @landlord_user.id)

    # House 1
    @house1 = House.create!(
      landlord: @landlord,
      name: "House One",
      mode: :room,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor1 = @house1.floors.create!(name: "Tầng 1", position: 1)
    @room1 = @floor1.rooms.create!(name: "101", max_slots: 2, tenants_count: 1, area: 25)
    @rental_unit1 = @room1.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    # House 2
    @house2 = House.create!(
      landlord: @landlord,
      name: "House Two",
      mode: :room,
      address_l1: "456 Other St",
      address_l2: "Ward 2",
      address_l3: "District 2",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor2 = @house2.floors.create!(name: "Tầng 1", position: 1)
    @room2 = @floor2.rooms.create!(name: "201", max_slots: 2, tenants_count: 1, area: 25)
    @rental_unit2 = @room2.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)

    # Tenant 1: staying in House 1
    @tenant_user1 = User.create!(
      fullname: "Tenant One",
      tel: "091#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 22.years.ago.to_date,
      address: "Tenant St 1",
      tel_verified_at: Time.current
    )
    @tenant1 = Tenant.find_or_create_by!(id: @tenant_user1.id)
    @tenant1.tenant_stays.create!(rental_unit: @rental_unit1, checkin_at: 1.month.ago, checkout_at: nil)

    # Tenant 2: staying in House 2
    @tenant_user2 = User.create!(
      fullname: "Tenant Two",
      tel: "092#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "Tenant St 2",
      tel_verified_at: Time.current
    )
    @tenant2 = Tenant.find_or_create_by!(id: @tenant_user2.id)
    @tenant2.tenant_stays.create!(rental_unit: @rental_unit2, checkin_at: 2.weeks.ago, checkout_at: nil)

    # Tenant 3: free / not staying anywhere
    @tenant_user3 = User.create!(
      fullname: "Tenant Three Free",
      tel: "093#{SecureRandom.random_number(10_000_000).to_s.rjust(7, '0')}",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 24.years.ago.to_date,
      address: "Tenant St 3",
      tel_verified_at: Time.current
    )
    @tenant3 = Tenant.find_or_create_by!(id: @tenant_user3.id)
  end

  test "invalid when tel format is wrong" do
    form = TenantLinkForm.new(tel: "12345", house: @house1)
    assert_not form.valid?
    assert form.errors[:tel].any?
  end

  test "invalid when tenant phone is unregistered" do
    form = TenantLinkForm.new(tel: "0999999999", house: @house1)
    assert_not form.valid?
    assert_includes form.errors[:tel], I18n.t("errors.tenant_tel_unregistered")
  end

  test "valid when tenant is registered and not currently linked anywhere" do
    form = TenantLinkForm.new(tel: @tenant_user3.tel, house: @house1)
    assert form.valid?
    assert_equal @tenant_user3, form.tenant
  end

  test "invalid with current house specific error when tenant is already staying in current house" do
    form = TenantLinkForm.new(tel: @tenant_user1.tel, house: @house1)
    assert_not form.valid?

    expected_location = @rental_unit1.location_info
    expected_msg = I18n.t("errors.tel_linked_current_house_with_location", location: expected_location)

    assert_includes form.errors[:tel], expected_msg
  end

  test "invalid with other house error when tenant is staying in a different house" do
    form = TenantLinkForm.new(tel: @tenant_user2.tel, house: @house1)
    assert_not form.valid?
    assert_includes form.errors[:tel], I18n.t("errors.tel_linked")
  end

  test "falls back to other house error when house context is not provided" do
    form = TenantLinkForm.new(tel: @tenant_user1.tel)
    assert_not form.valid?
    assert_includes form.errors[:tel], I18n.t("errors.tel_linked")
  end
end
