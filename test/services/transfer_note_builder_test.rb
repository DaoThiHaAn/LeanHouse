require "test_helper"

class TransferNoteBuilderTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      fullname: "Nguyễn Văn A",
      tel: "0905556677",
      password: "Password123",
      password_confirmation: "Password123",
      role: "landlord",
      sex: "male",
      bday: 30.years.ago.to_date,
      address: "456 Tran Hung Dao",
      tel_verified_at: Time.current
    )
    @landlord = Landlord.find_or_create_by!(id: @user.id)
    @house = House.create!(
      landlord: @landlord,
      name: "Nhà Trọ Xanh",
      mode: :room,
      address_l1: "456 Tran Hung Dao",
      address_l2: "Ward 2",
      address_l3: "District 5",
      floors_count: 1,
      inv_creation_date: 1
    )
    @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 1)
    @room = @floor.rooms.create!(name: "Phòng 101", max_slots: 2, tenants_count: 0, area: 25.0)

    @invoice = @house.invoices.build(
      code: "HD26092026-P101-ABCD",
      title: "Tiền phòng tháng 9",
      room: @room,
      created_by: @user,
      billing_month: Date.new(2026, 9, 1),
      due_date: Date.new(2026, 9, 10),
      note: "Phí dịch vụ gửi xe tháng 09/2026."
    )
  end

  test "default template uses invoice_code and preserves hyphens" do
    note = TransferNoteBuilder.build(nil, @invoice)
    assert_equal "HD26092026-P101-ABCD", note
  end

  test "does not automatically append invoice.note" do
    note = TransferNoteBuilder.build(nil, @invoice)
    assert_not_includes note, "DICH VU"
    assert_not_includes note, "GUI XE"
  end

  test "custom template with Vietnamese unaccenting" do
    note = TransferNoteBuilder.build("{room_name} {invoice_code}", @invoice)
    assert_equal "PHONG 101 HD26092026-P101-ABCD", note
  end

  test "truncates to 50 characters max" do
    long_template = "THIS IS A VERY LONG TEMPLATE THAT WILL DEFINITELY EXCEED FIFTY CHARACTERS AND SHOULD BE TRUNCATED"
    note = TransferNoteBuilder.build(long_template, @invoice)
    assert note.length <= 50
  end

  test "sanitize converts Vietnamese accents and d/D to unaccented uppercase" do
    raw = "Hóa đơn tiền phòng Đống Đa: @#$ 101"
    cleaned = TransferNoteBuilder.sanitize(raw)
    assert_equal "HOA DON TIEN PHONG DONG DA 101", cleaned
  end

  test "sanitize strips special symbols while preserving hyphens and spaces" do
    raw = "HD-26092026_ROOM*101!"
    cleaned = TransferNoteBuilder.sanitize(raw)
    assert_equal "HD-26092026ROOM101", cleaned
  end
end
