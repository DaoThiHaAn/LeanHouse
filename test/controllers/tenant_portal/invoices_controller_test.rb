require "test_helper"

class TenantPortal::InvoicesControllerTest < ActionDispatch::IntegrationTest
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

    @other_tenant_user = User.create!(
      fullname: "Other Tenant",
      tel: "0909998877",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 23.years.ago.to_date,
      address: "789 Other Rd",
      tel_verified_at: Time.current
    )
    @other_tenant = Tenant.find_or_create_by!(id: @other_tenant_user.id)

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

    @floor = @house.floors.create!(name: "Floor 1", position: 1, rooms_count: 2)
    @room = @floor.rooms.create!(name: "Room 101", max_slots: 2, tenants_count: 1, area: 25.0)
    @other_room = @floor.rooms.create!(name: "Room 102", max_slots: 2, tenants_count: 1, area: 25.0)

    @rental_unit = @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)
    @other_rental_unit = @other_room.create_rental_unit!(rent: 3_500_000, deposit: 3_500_000)

    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 2.months.ago,
      checkout_at: nil
    )

    @other_tenant_stay = TenantStay.create!(
      rental_unit: @other_rental_unit,
      tenant: @other_tenant,
      checkin_at: 2.months.ago,
      checkout_at: nil
    )

    @billing_month = Date.current.beginning_of_month

    @invoice = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-101-TEN1",
      title: "Tiền phòng tháng này",
      room: @room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 3_000_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_000_000
    )

    @other_invoice = @house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-102-TEN2",
      title: "Tiền phòng phòng khác",
      room: @other_room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 3_500_000,
      total_discount: 0,
      total_addition: 0,
      total_amount: 3_500_000
    )
  end

  def sign_in_as(user)
    post handle_login_path, params: {
      user: {
        tel: user.tel,
        password: "Password123",
        role: user.role
      }
    }
  end

  test "tenant can view pending invoice with confirm payment button and without undo button" do
    sign_in_as(@tenant_user)

    get tenant_invoice_path(@invoice)
    assert_response :success

    assert_select "button[data-bs-target='#tenantMarkPaidModal']", text: /#{I18n.t("invoice.submit_tenant_payment")}/
    assert_select "button[data-bs-target='#undoPaidModal']", 0
    assert_select "form[action='#{mark_paid_tenant_invoice_path(@invoice)}']"
  end

  test "tenant can mark invoice as paid with optional proof image and note" do
    sign_in_as(@tenant_user)

    file = fixture_file_upload("normal.png", "image/png")

    patch mark_paid_tenant_invoice_path(@invoice),
          params: {
            payment_method: "transfer",
            payment_proof: file,
            note: "Em đã chuyển khoản qua Vietcombank"
          }

    assert_redirected_to tenant_invoice_path(@invoice)
    follow_redirect!
    assert_includes response.body, I18n.t("invoice.payment_submitted_success")

    @invoice.reload
    assert_predicate @invoice, :paid?
    assert_equal "transfer", @invoice.payment_method
    assert_equal @tenant_user.id, @invoice.paid_by_id
    assert_equal "tenant", @invoice.paid_by_role
    assert_not_nil @invoice.paid_at
    assert_predicate @invoice.payment_proof, :attached?
    assert_includes @invoice.note, "Em đã chuyển khoản qua Vietcombank"

    # Verifies paid invoice shows proof thumbnail and completed badge, but no undo button
    get tenant_invoice_path(@invoice)
    assert_response :success
    assert_select ".payment-proof-thumb"
    assert_select "[data-bs-target='#tenantViewPaymentProofModal']"
    assert_select "button[data-bs-target='#undoPaidModal']", 0
  end

  test "tenant viewing paid invoice without proof image displays no proof text" do
    sign_in_as(@tenant_user)

    @invoice.update!(
      status: :paid,
      paid_at: Time.current,
      payment_method: "cash",
      paid_by: @tenant_user,
      paid_by_role: "tenant"
    )

    get tenant_invoice_path(@invoice)
    assert_response :success
    assert_select ".payment-proof-thumb", 0
    assert_includes response.body, I18n.t("invoice.no_payment_proof")
  end

  test "tenant cannot mark another tenant invoice as paid" do
    sign_in_as(@tenant_user)

    patch mark_paid_tenant_invoice_path(@other_invoice),
          params: { payment_method: "transfer" }
    assert_response :not_found
  end

  test "tenant sees previous undo reason banner if landlord undid payment" do
    sign_in_as(@tenant_user)

    @invoice.update!(
      status: :pending,
      undo_reason: "Chưa nhận được tiền trong tài khoản MB",
      undone_at: Time.current,
      undone_by: @landlord_user
    )

    get tenant_invoice_path(@invoice)
    assert_response :success
    assert_select ".undo-reason-banner" do
      assert_select ".undo-reason-title", text: /#{I18n.t('invoice.previous_undo_alert')}/
      assert_select ".undo-reason-text", text: /Chưa nhận được tiền trong tài khoản MB/
    end
  end

  test "in room invoice with multiple tenants, when a tenant pays, roommate and landlord receive distinct notifications" do
    bed_house = House.create!(
      landlord: @landlord,
      name: "Dorm House",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = bed_house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 201", max_slots: 2, tenants_count: 2, area: 30.0)

    bed1 = room.beds.create!(name: "Bed A")
    bed2 = room.beds.create!(name: "Bed B")
    ru1 = bed1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    ru2 = bed2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    # Tenant 1 stay
    @tenant_stay.update!(checkout_at: 1.day.ago)
    TenantStay.create!(rental_unit: ru1, tenant: @tenant, checkin_at: 1.month.ago)

    # Roommate stay
    roommate_user = User.create!(
      fullname: "Roommate B",
      tel: "0903334455",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "female",
      bday: 21.years.ago.to_date,
      address: "456 Roommate St",
      tel_verified_at: Time.current
    )
    roommate = Tenant.find_or_create_by!(id: roommate_user.id)
    TenantStay.create!(rental_unit: ru2, tenant: roommate, checkin_at: 1.month.ago)

    room_invoice = bed_house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-201-ROOM",
      title: "Tiền điện nước phòng",
      room: room,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :room,
      status: :pending,
      subtotal: 500_000,
      total_amount: 500_000
    )

    sign_in_as(@tenant_user)

    assert_difference -> { Noticed::Notification.count }, 3 do
      patch mark_paid_tenant_invoice_path(room_invoice),
            params: { payment_method: "transfer" }
    end

    # Check landlord notification
    landlord_noti = @landlord_user.notifications.last
    assert_includes landlord_noti.message, "Tenant Le"
    assert_includes landlord_noti.message, "Room 201"

    # Check roommate notification
    roommate_noti = roommate_user.notifications.last
    assert_includes roommate_noti.title, "Hóa đơn phòng"
    assert_includes roommate_noti.message, "Bạn cùng phòng Tenant Le"

    # Check payer notification
    payer_noti = @tenant_user.notifications.last
    assert_includes payer_noti.title, "Đã gửi xác nhận thanh toán"
  end

  test "in individual invoice, only the target tenant and landlord receive notifications, not roommates" do
    bed_house = House.create!(
      landlord: @landlord,
      name: "Dorm House Ind",
      mode: :bed,
      address_l1: "123 Main St",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    floor = bed_house.floors.create!(name: "Floor 1", position: 1, rooms_count: 1)
    room = floor.rooms.create!(name: "Room 401", max_slots: 2, tenants_count: 2, area: 30.0)

    bed1 = room.beds.create!(name: "Bed 1")
    bed2 = room.beds.create!(name: "Bed 2")
    ru1 = bed1.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)
    ru2 = bed2.create_rental_unit!(rent: 1_500_000, deposit: 1_500_000)

    @tenant_stay.update!(checkout_at: 1.day.ago)
    TenantStay.create!(rental_unit: ru1, tenant: @tenant, checkin_at: 1.month.ago)

    roommate_user = User.create!(
      fullname: "Roommate Dan",
      tel: "0903338899",
      password: "Password123",
      password_confirmation: "Password123",
      role: "tenant",
      sex: "male",
      bday: 21.years.ago.to_date,
      address: "456 Dan St",
      tel_verified_at: Time.current
    )
    roommate = Tenant.find_or_create_by!(id: roommate_user.id)
    TenantStay.create!(rental_unit: ru2, tenant: roommate, checkin_at: 1.month.ago)

    ind_invoice = bed_house.invoices.create!(
      code: "HD#{Date.current.strftime('%y%m')}-401-IND",
      title: "Tiền phòng cá nhân",
      room: room,
      tenant: @tenant,
      created_by: @landlord_user,
      billing_month: @billing_month,
      due_date: Date.current + 5.days,
      invoice_type: :individual,
      status: :pending,
      subtotal: 1_500_000,
      total_amount: 1_500_000
    )

    # 1. Roommate cannot access or pay this individual invoice
    sign_in_as(roommate_user)
    patch mark_paid_tenant_invoice_path(ind_invoice),
          params: { payment_method: "transfer" }
    assert_response :not_found

    # 2. Target tenant can pay, and exactly 2 notifications are created (Landlord & Target tenant only, 0 to roommate)
    sign_in_as(@tenant_user)

    assert_difference -> { roommate_user.notifications.count }, 0 do
      assert_difference -> { Noticed::Notification.count }, 2 do
        patch mark_paid_tenant_invoice_path(ind_invoice),
              params: { payment_method: "transfer" }
      end
    end

    assert_redirected_to tenant_invoice_path(ind_invoice)
    assert_predicate ind_invoice.reload, :paid?
  end
end
