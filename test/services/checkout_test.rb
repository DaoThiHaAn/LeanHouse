require "test_helper"

class CheckoutTest < ActiveSupport::TestCase
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
      checkin_at: Date.current
    )

    @vehicle = Vehicle.create!(
      tenant: @tenant,
      house: @house,
      license_plate: "59A-12345",
      vehicle_type: :motorbike,
      brand: "Honda",
      model: "Vision"
    )
  end

  test "checkout automatically hard deletes tenant vehicles in the house" do
    assert_equal 1, @house.vehicles.where(tenant: @tenant).count

    Checkout.call(
      house: @house,
      tenant_stay: @tenant_stay
    )

    assert_not_nil @tenant_stay.reload.checkout_at
    assert_equal 0, @house.vehicles.where(tenant: @tenant).count
    assert_not Vehicle.exists?(@vehicle.id)
  end

  test "checkout approves approved_request and rejects all other pending/handling requests" do
    approved_leave = LeaveHouseRequest.create!
    approved_req = @house.requests.create!(
      tenant: @tenant,
      requestable: approved_leave,
      status: :pending
    )

    other_leave = LeaveHouseRequest.create!
    other_req = @house.requests.create!(
      tenant: @tenant,
      requestable: other_leave,
      status: :pending
    )

    repair = RepairRequest.create!(title: "Sửa vòi nước", content: "Bị rò rỉ")
    repair_req = @house.requests.create!(
      tenant: @tenant,
      requestable: repair,
      status: :handling,
      resolved_by: @landlord_user,
      resolved_at: Time.current
    )

    vehicle_req = VehicleRequest.new(
      license_plate: "59A-99999",
      vehicle_type: :motorbike,
      consent_given_at: Time.current
    )
    vehicle_req.registration_card_image.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "reg.png",
      content_type: "image/png"
    )
    vehicle_req.vehicle_photo.attach(
      io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
      filename: "photo.png",
      content_type: "image/png"
    )
    vehicle_req.save!
    v_req = @house.requests.create!(
      tenant: @tenant,
      requestable: vehicle_req,
      status: :pending
    )

    assert_no_difference -> { Noticed::Event.where(type: "RequestResolvedNotifier").count } do
      Checkout.call(
        house: @house,
        tenant_stay: @tenant_stay,
        approved_request: approved_req
      )
    end

    assert_equal "approved", approved_req.reload.status
    assert_not_nil approved_req.resolved_at

    expected_reason = I18n.t("request.rejection_reason_checkout")
    assert_equal "rejected", other_req.reload.status
    assert_equal expected_reason, other_req.rejection_reason

    assert_equal "rejected", repair_req.reload.status
    assert_equal expected_reason, repair_req.rejection_reason

    assert_equal "rejected", v_req.reload.status
    assert_equal expected_reason, v_req.rejection_reason
    assert_not vehicle_req.reload.registration_card_image.attached?
  end

  test "checkout rejects all pending requests if no approved_request is specified (e.g. manual landlord removal)" do
    leave_req = LeaveHouseRequest.create!
    req = @house.requests.create!(
      tenant: @tenant,
      requestable: leave_req,
      status: :pending
    )

    Checkout.call(
      house: @house,
      tenant_stay: @tenant_stay
    )

    assert_equal "rejected", req.reload.status
    assert_equal I18n.t("request.rejection_reason_checkout"), req.rejection_reason
  end

  test "checkout raises PendingInvoicesError when tenant has pending individual or custom invoices" do
    inv = @house.invoices.create!(
      code: "HD-PENDING-01",
      title: "Hóa đơn dịch vụ cá nhân",
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :custom,
      status: :pending,
      subtotal: 500_000,
      total_amount: 500_000
    )

    error = assert_raises(Checkout::PendingInvoicesError) do
      Checkout.call(house: @house, tenant_stay: @tenant_stay)
    end

    assert_includes error.invoices, inv
    assert_nil @tenant_stay.reload.checkout_at
  end

  test "checkout raises PendingInvoicesError when room has pending invoice and tenant is only occupant left" do
    inv = @house.invoices.create!(
      code: "HD-ROOM-PENDING-01",
      title: "Hóa đơn phòng 101",
      room: @room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 3_000_000,
      total_amount: 3_000_000
    )

    assert_equal 1, @room.active_staying_tenant_users.count

    error = assert_raises(Checkout::PendingInvoicesError) do
      Checkout.call(house: @house, tenant_stay: @tenant_stay)
    end

    assert_includes error.invoices, inv
    assert_nil @tenant_stay.reload.checkout_at
  end

  test "checkout succeeds with pending room invoice if another occupant remains, but blocks the last occupant" do
    bed_house = House.create!(
      landlord: @landlord,
      name: "Bed House Test",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = bed_house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 201", max_slots: 2, tenants_count: 2, area: 25.0)
    bed1 = room.beds.create!(name: "Bed 1")
    bed2 = room.beds.create!(name: "Bed 2")
    ru1 = bed1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    ru2 = bed2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    u1 = User.create!(fullname: "Tenant Mot", tel: "0908887766", password: "Password123", password_confirmation: "Password123", role: "tenant", sex: "male", bday: 24.years.ago.to_date, address: "St", tel_verified_at: Time.current)
    t1 = Tenant.find_or_create_by!(id: u1.id)
    u2 = User.create!(fullname: "Tenant Hai", tel: "0909998877", password: "Password123", password_confirmation: "Password123", role: "tenant", sex: "female", bday: 23.years.ago.to_date, address: "St", tel_verified_at: Time.current)
    t2 = Tenant.find_or_create_by!(id: u2.id)

    stay1 = TenantStay.create!(rental_unit: ru1, tenant: t1, checkin_at: Date.current)
    stay2 = TenantStay.create!(rental_unit: ru2, tenant: t2, checkin_at: Date.current)

    inv = bed_house.invoices.create!(
      code: "HD-BED-ROOM-01",
      title: "Hóa đơn điện nước chung phòng 201",
      room: room,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 400_000,
      total_amount: 400_000
    )

    # When 2 occupants are staying in the room, checking out tenant 1 succeeds because tenant 2 remains
    assert_equal 2, room.active_staying_tenant_users.count
    assert_nothing_raised do
      Checkout.call(house: bed_house, tenant_stay: stay1)
    end
    assert_not_nil stay1.reload.checkout_at

    # Now only tenant 2 remains in room 201. Checking out tenant 2 must be blocked by the pending room invoice!
    assert_equal 1, room.active_staying_tenant_users.count
    assert_raises(Checkout::PendingInvoicesError) do
      Checkout.call(house: bed_house, tenant_stay: stay2)
    end
    assert_nil stay2.reload.checkout_at
  end

  test "checkout succeeds when invoices are paid or cancelled" do
    @house.invoices.create!(
      code: "HD-PAID-01",
      title: "Hóa đơn đã thanh toán",
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :custom,
      status: :paid,
      paid_at: Time.current,
      payment_method: "cash",
      subtotal: 500_000,
      total_amount: 500_000
    )
    @house.invoices.create!(
      code: "HD-CANCELLED-01",
      title: "Hóa đơn đã hủy",
      room: @room,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: Date.current.beginning_of_month,
      due_date: Date.current + 5.days,
      invoice_type: :custom,
      status: :cancelled,
      subtotal: 300_000,
      total_amount: 300_000
    )

    assert_nothing_raised do
      Checkout.call(house: @house, tenant_stay: @tenant_stay)
    end
    assert_not_nil @tenant_stay.reload.checkout_at
  end
end
