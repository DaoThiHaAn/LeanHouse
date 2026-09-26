require "test_helper"

class AdminPortal::UploadedFilesControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  def setup
    @admin = Admin.create!(
      email: "admin_files@leanhouse.vn",
      fullname: "File Moderator Admin",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "super_admin",
      is_active: true
    )

    @landlord = User.create!(
      fullname: "Nguyen Landlord",
      tel: "0901234567",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "123 Main St",
      tel_verified_at: Time.current
    )
    Landlord.find_or_create_by!(id: @landlord.id)

    @tenant = User.create!(
      fullname: "Le Tenant",
      tel: "0907654321",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: "tenant",
      sex: "female",
      bday: 22.years.ago.to_date,
      address: "456 Side St",
      tel_verified_at: Time.current
    )
    Tenant.find_or_create_by!(id: @tenant.id)

    # Attach sample files
    @tenant.avatar.attach(
      io: StringIO.new("fake image bytes"),
      filename: "user_avatar.png",
      content_type: "image/png"
    )
    @user_attachment = @tenant.avatar.attachment
  end

  def login_as(admin)
    post admin_handle_login_url, params: { email: admin.email, password: "Password123!" }
  end

  test "unauthenticated user cannot access uploaded files index" do
    get admin_uploaded_files_url
    assert_redirected_to admin_login_url
  end

  test "unauthenticated user cannot access uploaded file show or destroy" do
    get admin_uploaded_file_url(@user_attachment)
    assert_redirected_to admin_login_url

    delete admin_uploaded_file_url(@user_attachment)
    assert_redirected_to admin_login_url
  end

  test "authenticated admin can view uploaded files index and stats" do
    login_as(@admin)
    get admin_uploaded_files_url
    assert_response :success
    assert_includes response.body, "user_avatar.png"
    assert_includes response.body, "Quy chế Kiểm duyệt"
  end

  test "uploaded files list paginates with 15 records per page" do
    login_as(@admin)

    # Create 16 additional user avatars so total attachments > 15
    16.times do |i|
      u = User.create!(
        fullname: "Nguyen Van User #{('A'..'Z').to_a[i]}",
        tel: "097#{i.to_s.rjust(7, '0')}",
        password: "Password123!",
        password_confirmation: "Password123!",
        role: "tenant",
        sex: "male",
        bday: 20.years.ago.to_date,
        address: "Address #{i}",
        is_active: true
      )
      u.avatar.attach(
        io: StringIO.new("fake image #{i}"),
        filename: "avatar_#{i}.png",
        content_type: "image/png"
      )
    end

    get admin_uploaded_files_url(page: 2)
    assert_response :success
    assert_select ".pagination"
    assert_select "span[data-pagination-total-pages]"
  end

  test "filter uploaded files by record_type" do
    login_as(@admin)
    get admin_uploaded_files_url, params: { record_type: "User" }
    assert_response :success
    assert_includes response.body, "user_avatar.png"

    get admin_uploaded_files_url, params: { record_type: "Contract" }
    assert_response :success
    assert_not_includes response.body, "user_avatar.png"
  end

  test "filter uploaded files by file_type" do
    login_as(@admin)
    get admin_uploaded_files_url, params: { file_type: "image" }
    assert_response :success
    assert_includes response.body, "user_avatar.png"

    get admin_uploaded_files_url, params: { file_type: "pdf" }
    assert_response :success
    assert_not_includes response.body, "user_avatar.png"
  end

  test "search uploaded files by keyword query" do
    login_as(@admin)
    get admin_uploaded_files_url, params: { q: "user_avatar" }
    assert_response :success
    assert_includes response.body, "user_avatar.png"

    get admin_uploaded_files_url, params: { q: "nonexistent_keyword_xyz" }
    assert_response :success
    assert_not_includes response.body, "user_avatar.png"
  end

  test "clear filter button is hidden by default and visible when filters are present" do
    login_as(@admin)
    get admin_uploaded_files_url
    assert_response :success
    assert_select "button[data-search-target='clearButton'].d-none"

    get admin_uploaded_files_url, params: { q: "avatar" }
    assert_response :success
    assert_select "button[data-search-target='clearButton']:not(.d-none)"

    get admin_uploaded_files_url, params: { record_type: "User" }
    assert_response :success
    assert_select "button[data-search-target='clearButton']:not(.d-none)"

    get admin_uploaded_files_url, params: { file_type: "image" }
    assert_response :success
    assert_select "button[data-search-target='clearButton']:not(.d-none)"
  end

  test "turbo frame request on index renders table partial" do
    login_as(@admin)
    get admin_uploaded_files_url, headers: { "Turbo-Frame" => "uploaded_files_table" }
    assert_response :success
    assert_includes response.body, "user_avatar.png"
  end

  test "show action renders file details" do
    login_as(@admin)
    get admin_uploaded_file_url(@user_attachment)
    assert_response :success
    assert_includes response.body, "user_avatar.png"
    assert_includes response.body, @tenant.fullname
  end

  test "show action via turbo frame renders file modal without full layout" do
    login_as(@admin)
    get admin_uploaded_file_url(@user_attachment), headers: { "Turbo-Frame" => "uploaded_file_detail_modal" }
    assert_response :success
    assert_includes response.body, "user_avatar.png"
    assert_not_includes response.body, "<!DOCTYPE html>"
  end

  test "admin can delete sensitive file and notify user" do
    login_as(@admin)

    assert_difference("ActiveStorage::Attachment.count", -1) do
      delete admin_uploaded_file_url(@user_attachment), params: {
        reason: "sensitive_content"
      }
    end

    assert_redirected_to admin_uploaded_files_url
    follow_redirect!
    assert_includes flash[:notice], "user_avatar.png"
    assert_not @tenant.reload.avatar.attached?
  end

  test "admin can delete file with custom reason via turbo stream" do
    login_as(@admin)

    assert_difference("ActiveStorage::Attachment.count", -1) do
      delete admin_uploaded_file_url(@user_attachment), params: {
        reason: "custom",
        custom_reason: "Ảnh đại diện vi phạm tiêu chuẩn cộng đồng"
      }, as: :turbo_stream
    end

    assert_response :success
    assert_match(/turbo-stream/, response.media_type)
    assert_not @tenant.reload.avatar.attached?
  end

  test "redirects gracefully when attachment not found" do
    login_as(@admin)
    get admin_uploaded_file_url(id: 999999)
    assert_redirected_to admin_uploaded_files_url
    assert_equal "Không tìm thấy tệp này hoặc tệp đã bị xóa.", flash[:alert]
  end

  test "admin can delete attachment on repair request and notify reporter and landlord" do
    landlord_model = Landlord.find(@landlord.id)
    tenant_model = Tenant.find(@tenant.id)

    house = House.create!(
      landlord: landlord_model,
      name: "Sunrise Villa",
      mode: :room,
      address_l1: "123 Sun Street",
      address_l2: "Ward 1",
      address_l3: "District 1",
      floors_count: 1,
      inv_creation_date: 1
    )

    repair_req = RepairRequest.create!(
      title: "Broken air conditioner",
      content: "Air conditioner leaking water"
    )
    Request.create!(
      tenant: tenant_model,
      house: house,
      requestable: repair_req,
      status: :pending
    )

    repair_req.images.attach(
      io: StringIO.new("fake ac photo"),
      filename: "ac_broken.jpg",
      content_type: "image/jpeg"
    )
    req_attachment = repair_req.images.attachments.first

    login_as(@admin)
    assert_difference("ActiveStorage::Attachment.count", -1) do
      delete admin_uploaded_file_url(req_attachment), params: {
        reason: "fraudulent_document"
      }
    end

    assert_redirected_to admin_uploaded_files_url
    assert_not repair_req.reload.images.attached?
  end
end
