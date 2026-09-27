require "test_helper"

class RequestTest < ActiveSupport::TestCase
  setup do
    @landlord_user = create_landlord(tel: "0901119911")
    @tenant_user = create_tenant(tel: "0902229911")

    @house = House.create!(
      landlord: @landlord_user.landlord,
      name: "Request Model House",
      mode: :room,
      address_l1: "123 Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )
    @repair = RepairRequest.create!(title: "Hư vòi nước", content: "Vòi nước bị rò rỉ")
    @request = @tenant_user.tenant.requests.create!(
      house: @house,
      requestable: @repair
    )
  end

  test "request initializes in pending status and is actionable" do
    assert @request.pending?
    assert @request.actionable?
  end

  test "approve! transitions status to approved and records resolved_at" do
    @request.approve!(@landlord_user)
    assert @request.approved?
    assert_equal @landlord_user, @request.resolved_by
    assert_not_nil @request.resolved_at
  end

  test "reject! transitions status to rejected and stores rejection reason" do
    @request.reject!(@landlord_user, "Không thuộc phạm vi bảo hành")
    assert @request.rejected?
    assert_equal "Không thuộc phạm vi bảo hành", @request.rejection_reason
    assert_not @request.actionable?
  end

  test "mark_as_overdue! transitions status to overdue and notifies tenant once" do
    assert_difference -> { Noticed::Notification.count }, 1 do
      @request.mark_as_overdue!
    end

    assert @request.overdue?
    noti = Noticed::Notification.last
    assert_equal @tenant_user, noti.recipient
    assert_equal "overdue", noti.event.params[:decision]

    # Calling mark_as_overdue! again on an already overdue request is a no-op
    assert_no_difference -> { Noticed::Notification.count } do
      @request.mark_as_overdue!
    end
  end
end
