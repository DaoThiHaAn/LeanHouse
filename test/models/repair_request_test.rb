require "test_helper"

class RepairRequestTest < ActiveSupport::TestCase
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

    @repair_req = RepairRequest.new(
      title: "Hỏng vòi nước bồn rửa",
      content: "Vòi nước bị rò rỉ liên tục từ tối qua, cần thợ kiểm tra gấp."
    )
  end

  test "valid repair request" do
    assert @repair_req.valid?
  end

  test "invalid without title" do
    @repair_req.title = ""
    assert_not @repair_req.valid?
    assert @repair_req.errors[:title].any?
  end

  test "invalid with title longer than 100 chars" do
    @repair_req.title = "A" * 101
    assert_not @repair_req.valid?
    assert @repair_req.errors[:title].any?
  end

  test "invalid without content" do
    @repair_req.content = ""
    assert_not @repair_req.valid?
    assert @repair_req.errors[:content].any?
  end

  test "invalid with content longer than 500 chars" do
    @repair_req.content = "A" * 501
    assert_not @repair_req.valid?
    assert @repair_req.errors[:content].any?
  end

  test "allows attaching valid images up to 5" do
    3.times do |i|
      @repair_req.images.attach(
        io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
        filename: "img_#{i}.png",
        content_type: "image/png"
      )
    end
    assert @repair_req.valid?
  end

  test "invalid when more than 5 images attached" do
    6.times do |i|
      @repair_req.images.attach(
        io: File.open(Rails.root.join("test/fixtures/files/normal.png")),
        filename: "img_#{i}.png",
        content_type: "image/png"
      )
    end
    assert_not @repair_req.valid?
    assert @repair_req.errors[:images].any?
  end

  test "multi-step handling lifecycle" do
    @repair_req.save!
    request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @repair_req,
      status: :pending
    )

    # 1. Start handling
    @repair_req.start_handling!(@landlord_user)
    assert_equal "handling", request.reload.status
    assert_equal @landlord_user, request.resolved_by
    assert_not_nil request.resolved_at

    # 2. Complete repair
    @repair_req.complete!(@landlord_user)
    assert_equal "completed", request.reload.status

    # 3. Cannot reject when completed
    assert_raises(RuntimeError) do
      @repair_req.reject!(@landlord_user, "Too late")
    end
  end

  test "rejection from pending state" do
    @repair_req.save!
    request = Request.create!(
      tenant: @tenant,
      house: @house,
      requestable: @repair_req,
      status: :pending
    )

    @repair_req.reject!(@landlord_user, "Không thuộc phạm vi bảo dưỡng của tòa nhà")
    assert_equal "rejected", request.reload.status
    assert_equal "Không thuộc phạm vi bảo dưỡng của tòa nhà", request.rejection_reason
    assert_equal @landlord_user, request.resolved_by
  end
end
