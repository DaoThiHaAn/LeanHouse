# frozen_string_literal: true

require "test_helper"

module AdminPortal
  class UploadedFilesHelperTest < ActionView::TestCase
    include AdminPortal::UploadedFilesHelper

    setup do
      @landlord_user = create_landlord(tel: "0907771111", fullname: "Chu Nha Test")
      @tenant_user = create_tenant(tel: "0907772222", fullname: "Khach Thue Test")

      @house = House.create!(
        landlord: @landlord_user.landlord,
        name: "Helper Test House",
        mode: :room,
        address_l1: "123 Helper St",
        address_l2: "Ward 1",
        address_l3: "District 1",
        floors_count: 1,
        inv_creation_date: 1
      )
      @floor = @house.floors.create!(name: "Tầng 1", position: 1, rooms_count: 0)
      @room = @floor.rooms.create!(name: "202", max_slots: 2, area: 25.0)
      @room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

      TenantStay.create!(
        tenant: @tenant_user.tenant,
        rental_unit: @room.rental_unit,
        checkin_at: 1.month.ago,
        has_contract: true
      )

      @contract = Contract.new(
        house: @house,
        landlord: @landlord_user.landlord,
        tenant: @tenant_user.tenant,
        name: "HD-HELPER",
        landlord_citizen_id: "079199000999",
        tenant_citizen_id: "079201000888",
        start_date: 1.month.ago.to_date,
        due_date: 5.months.from_now.to_date
      )
      @contract.documents.attach(
        io: StringIO.new("doc"),
        filename: "doc.jpg",
        content_type: "image/jpeg"
      )
      @contract.save!

      @bank = Bank.find_or_create_by!(code: "VCB") do |b|
        b.name = "Vietcombank"
        b.short_name = "Vietcombank"
        b.bin = "970436"
      end
      @bank_account = @landlord_user.landlord.bank_accounts.create!(
        bank: @bank,
        account_number: "9876543210",
        account_holder: "CHU NHA TEST",
        is_default: true
      )
    end

    FakeAttachment = Struct.new(:record, :record_type, :record_id, :blob)
    FakeBlob = Struct.new(:content_type, :filename, :attachments)

    test "record_type_badge_text and record_type_badge_class cover known and unknown types" do
      %w[User Contract ServiceUsageLog Invoice RepairRequest VehicleRequest Vehicle House ActiveStorage::VariantRecord UnknownType].each do |type|
        assert_not_empty record_type_badge_text(type)
        assert_not_empty record_type_badge_class(type)
      end
    end

    test "user_role_badge_text covers all roles and nil/non-role objects" do
      assert_equal "", user_role_badge_text(nil)
      assert_equal "", user_role_badge_text(Object.new)

      %w[landlord tenant admin super_admin support custom_role].each do |role|
        u = Struct.new(:role).new(role)
        assert_not_empty user_role_badge_text(u)
      end
    end

    test "file_type_badge covers image, video, pdf, document, and nil blob" do
      assert_equal "", file_type_badge(FakeAttachment.new(nil, nil, nil, nil))

      img_att = FakeAttachment.new(nil, "User", 1, FakeBlob.new("image/png", "a.png", []))
      assert_includes file_type_badge(img_att), "PNG"

      vid_att = FakeAttachment.new(nil, "User", 1, FakeBlob.new("video/mp4", "v.mp4", []))
      assert_includes file_type_badge(vid_att), "MP4"

      pdf_att = FakeAttachment.new(nil, "Contract", 1, FakeBlob.new("application/pdf", "c.pdf", []))
      assert_includes file_type_badge(pdf_att), "PDF"

      doc_att = FakeAttachment.new(nil, "Contract", 1, FakeBlob.new("text/plain", "t.txt", []))
      assert_includes file_type_badge(doc_att), "description"
    end

    test "find_senders_for_attachment and record_friendly_description and record_admin_link across models" do
      assert_equal [], find_senders_for_attachment(FakeAttachment.new(nil, "Unknown", 99, nil))
      assert_nil record_admin_link(FakeAttachment.new(nil, "Unknown", 99, nil))
      assert_includes record_friendly_description(FakeAttachment.new(nil, "Unknown", 99, nil)), "#99"

      # User
      user_att = FakeAttachment.new(@landlord_user, "User", @landlord_user.id, nil)
      assert_equal [ @landlord_user ], find_senders_for_attachment(user_att)
      assert_includes record_friendly_description(user_att), @landlord_user.fullname
      assert_not_nil record_admin_link(user_att)

      # Contract
      contract_att = FakeAttachment.new(@contract, "Contract", @contract.id, nil)
      assert_includes find_senders_for_attachment(contract_att), @tenant_user
      assert_includes record_friendly_description(contract_att), "HD-HELPER"
      assert_not_nil record_admin_link(contract_att)

      # House
      house_att = FakeAttachment.new(@house, "House", @house.id, nil)
      assert_equal [ @landlord_user ], find_senders_for_attachment(house_att)
      assert_includes record_friendly_description(house_att), @house.name
      assert_not_nil record_admin_link(house_att)

      # Vehicle
      vehicle = Vehicle.create!(
        tenant: @tenant_user.tenant,
        house: @house,
        vehicle_type: "bicycle",
        brand: "Martin",
        license_plate: "BIKE-01"
      )
      veh_att = FakeAttachment.new(vehicle, "Vehicle", vehicle.id, nil)
      assert_includes find_senders_for_attachment(veh_att), @tenant_user
      assert_includes record_friendly_description(veh_att), "BIKE-01"
      assert_nil record_admin_link(veh_att)

      # ServiceUsageLog (with and without submitted_by)
      service = @house.services.create!(name: "Nước")
      variant = service.service_variants.create!(unit: :per_m3, fee: 15_000, is_real_time: true)
      log = ServiceUsageLog.create!(
        room: @room,
        service: service,
        service_variant: variant,
        service_name: "Nước",
        unit: "m3",
        unit_price: 15_000,
        billing_month: Date.current.beginning_of_month,
        start_date: Date.current.beginning_of_month,
        end_date: Date.current.end_of_month,
        prev_reading: 10,
        latest_reading: 20,
        submitted_by: @tenant_user,
        is_confirmed: true
      )
      log_att = FakeAttachment.new(log, "ServiceUsageLog", log.id, nil)
      assert_equal [ @tenant_user ], find_senders_for_attachment(log_att)
      log.submitted_by = nil
      assert_includes find_senders_for_attachment(log_att), @landlord_user
      assert_includes record_friendly_description(log_att), "Nước"

      # Invoice (with and without paid_by)
      inv = Invoice.create!(
        house: @house,
        room: @room,
        created_by: @landlord_user,
        bank_account: @bank_account,
        invoice_type: :room,
        code: "HD-UPL-01",
        title: "Hóa đơn test",
        billing_month: Date.current.beginning_of_month,
        start_date: Date.current.beginning_of_month,
        end_date: Date.current.end_of_month,
        due_date: Date.current + 3.days,
        subtotal: 100_000,
        total_amount: 100_000,
        paid_by: @tenant_user
      )
      inv_att = FakeAttachment.new(inv, "Invoice", inv.id, nil)
      assert_equal [ @tenant_user ], find_senders_for_attachment(inv_att)
      inv.paid_by = nil
      assert_includes find_senders_for_attachment(inv_att), @landlord_user
      assert_includes record_friendly_description(inv_att), "Hóa đơn test"
      assert_not_nil record_admin_link(inv_att)

      # RepairRequest & VehicleRequest
      repair_req = RepairRequest.create!(title: "Hỏng vòi nước", content: "Rò rỉ nước")
      Request.create!(tenant: @tenant_user.tenant, house: @house, requestable: repair_req, status: :pending)
      rep_att = FakeAttachment.new(repair_req, "RepairRequest", repair_req.id, nil)
      assert_includes find_senders_for_attachment(rep_att), @tenant_user
      assert_includes record_friendly_description(rep_att), "Hỏng vòi nước"
      assert_not_nil record_admin_link(rep_att)

      # Fallback record types
      user_wrapper = Struct.new(:user).new(@tenant_user)
      assert_equal [ @tenant_user ], find_senders_for_attachment(FakeAttachment.new(user_wrapper, "Other", 1, nil))

      submitted_wrapper = Struct.new(:submitted_by).new(@landlord_user)
      assert_equal [ @landlord_user ], find_senders_for_attachment(FakeAttachment.new(submitted_wrapper, "Other", 1, nil))

      tenant_wrapper = Struct.new(:tenant).new(@tenant_user.tenant)
      assert_equal [ @tenant_user ], find_senders_for_attachment(FakeAttachment.new(tenant_wrapper, "Other", 1, nil))

      landlord_wrapper = Struct.new(:landlord).new(@landlord_user.landlord)
      assert_equal [ @landlord_user ], find_senders_for_attachment(FakeAttachment.new(landlord_wrapper, "Other", 1, nil))

      empty_wrapper = Object.new
      assert_equal [], find_senders_for_attachment(FakeAttachment.new(empty_wrapper, "Other", 1, nil))
    end
  end
end
