# frozen_string_literal: true

require "test_helper"

class RequestResolutionWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @landlord_user = create_landlord(tel: "0901002003", password: "Password123")
    @landlord = @landlord_user.landlord

    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Liên Thông",
      mode: :room,
      address_l1: "15 Nguyễn Thị Minh Khai",
      address_l2: "Phường Bến Nghé",
      address_l3: "TP.HCM",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "P.105", area: 20.0, max_slots: 2, tenants_count: 1)

    @tenant_user = create_tenant(tel: "0904005006", password: "Password123")
    @tenant = @tenant_user.tenant

    @rental_unit = @room.rental_unit || @room.create_rental_unit!(rent: 2_800_000, deposit: 2_800_000)
    @tenant_stay = TenantStay.create!(
      rental_unit: @rental_unit,
      tenant: @tenant,
      checkin_at: 1.month.ago,
      checkout_at: nil
    )
  end

  test "full repair request lifecycle from tenant submission to landlord handling and completion" do
    # Step 1: Tenant logs in and creates a repair request
    post handle_login_path, params: {
      user: { tel: @tenant_user.tel, password: "Password123", role: "tenant" }
    }
    assert_response :redirect

    assert_difference -> { Request.count }, 1 do
      post tenant_repair_requests_path, params: {
        repair_request: {
          title: "Hỏng công tắc đèn ban công",
          content: "Bật tắt nhiều lần nhưng đèn ngoài ban công không sáng."
        }
      }
    end
    assert_redirected_to tenant_requests_path

    created_request = Request.last
    assert_equal "pending", created_request.status
    assert_equal @tenant.id, created_request.tenant_id

    delete logout_path

    # Step 2: Landlord logs in and marks request as 'handling', then 'completed'
    post handle_login_path, params: {
      user: { tel: @landlord_user.tel, password: "Password123", role: "landlord" }
    }
    assert_response :redirect

    patch handle_landlord_request_path(created_request), params: { decision: "handling" }
    assert_equal "handling", created_request.reload.status
    assert_equal @landlord_user.id, created_request.resolved_by_id

    assert_difference -> { Noticed::Notification.where(recipient: @tenant_user).count }, 1 do
      patch handle_landlord_request_path(created_request), params: { decision: "completed" }
    end

    assert_equal "completed", created_request.reload.status
  end
end
