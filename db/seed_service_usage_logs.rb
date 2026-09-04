# frozen_string_literal: true

puts "== Seeding Service Usage Logs and Real UI Test Data =="

h20 = House.find_by(id: 20)
h13 = House.find_by(id: 13)

landlord = User.find_by(id: 2) || User.find_by(role: :landlord)

names = [
  "Nguyễn Văn An", "Trần Thị Bình", "Lê Văn Cường", "Phạm Minh Đức",
  "Hoàng Thị Hoa", "Vũ Văn Hải", "Đặng Thị Mai", "Bùi Văn Nam",
  "Đỗ Thị Nga", "Hồ Văn Phong", "Ngô Thị Quỳnh", "Dương Văn Sơn"
]

[ h20, h13 ].compact.each do |house|
  puts "Processing House #{house.id}: #{house.name}..."

  dien_variant = house.service_variants.joins(:service).where(is_real_time: true, unit: "per_kwh").first ||
                 house.service_variants.joins(:service).where(is_real_time: true).first

  nuoc_variant = house.service_variants.joins(:service).where(is_real_time: true, unit: "per_m3").first

  wifi_variant = house.service_variants.joins(:service).where(is_real_time: false).first

  sample_photo_path = Rails.root.join("app/assets/images/banner.png")

  rooms = house.rooms.order(:id).to_a
  rooms.each_with_index do |room, idx|
    # Ensure rental_unit exists
    rental_unit = room.rental_unit || room.create_rental_unit!(rent: 3_000_000, deposit: 3_000_000)

    # Assign unique tenant stay if none
    if room.tenant_stays.staying.empty?
      tel_num = sprintf("0978%02d%04d", house.id, (room.id * 7) % 10000)
      tenant_user = User.find_or_create_by!(tel: tel_num) do |u|
        u.fullname = names[idx % names.size]
        u.role = :tenant
        u.password = "password123"
        u.password_confirmation = "password123"
        u.bday = Date.new(2000, 1, 1)
        u.address = "Hà Nội"
        u.sex = "male"
        u.is_active = true
      end
      tenant = Tenant.find_or_create_by!(id: tenant_user.id)

      # Check if this tenant is already staying anywhere
      unless TenantStay.staying.where(tenant_id: tenant.id).exists?
        TenantStay.create!(
          tenant: tenant,
          rental_unit: rental_unit,
          checkin_at: 2.months.ago,
          has_contract: false
        )
        puts "  Assigned tenant #{tenant_user.fullname} to Room #{room.name}"
      end
    end

    # Ensure RoomService connections
    [ dien_variant, nuoc_variant, wifi_variant ].compact.each do |variant|
      RoomService.find_or_create_by!(room: room, service_variant: variant) do |rs|
        rs.service = variant.service
      end
    end
  end

  # Create logs for Room 1 & Room 2 in House 20
  r1 = rooms[0]
  r2 = rooms[1]
  r3 = rooms[2]
  tenant_user1 = r1&.tenant_stays&.staying&.first&.tenant&.user || landlord

  # August 2026 logs (Confirmed)
  aug_month = Date.new(2026, 8, 1)
  if r1 && dien_variant
    log_aug_dien = ServiceUsageLog.find_or_initialize_by(room: r1, service_variant: dien_variant, billing_month: aug_month)
    log_aug_dien.assign_attributes(
      service: dien_variant.service,
      service_name: dien_variant.service.name,
      unit: dien_variant.human_unit,
      unit_price: dien_variant.fee,
      prev_reading: 100,
      latest_reading: 245,
      usage_quantity: 145,
      start_date: aug_month.beginning_of_month,
      end_date: aug_month.end_of_month,
      is_confirmed: true,
      confirmed_at: aug_month.end_of_month,
      confirmed_by: landlord,
      submitted_by: landlord
    )
    log_aug_dien.save!
  end

  if r1 && nuoc_variant
    log_aug_nuoc = ServiceUsageLog.find_or_initialize_by(room: r1, service_variant: nuoc_variant, billing_month: aug_month)
    log_aug_nuoc.assign_attributes(
      service: nuoc_variant.service,
      service_name: nuoc_variant.service.name,
      unit: nuoc_variant.human_unit,
      unit_price: nuoc_variant.fee,
      prev_reading: 40,
      latest_reading: 58,
      usage_quantity: 18,
      start_date: aug_month.beginning_of_month,
      end_date: aug_month.end_of_month,
      is_confirmed: true,
      confirmed_at: aug_month.end_of_month,
      confirmed_by: landlord,
      submitted_by: landlord
    )
    log_aug_nuoc.save!
  end

  # September 2026 logs
  sep_month = Date.new(2026, 9, 1)

  # Room 1: Unconfirmed tenant submissions with photo!
  if r1 && dien_variant
    log_sep_dien = ServiceUsageLog.find_or_initialize_by(room: r1, service_variant: dien_variant, billing_month: sep_month)
    log_sep_dien.assign_attributes(
      service: dien_variant.service,
      service_name: dien_variant.service.name,
      unit: dien_variant.human_unit,
      unit_price: dien_variant.fee,
      prev_reading: 245,
      latest_reading: 395,
      usage_quantity: 150,
      start_date: sep_month.beginning_of_month,
      end_date: sep_month.end_of_month,
      is_confirmed: false,
      submitted_by: tenant_user1
    )
    if File.exist?(sample_photo_path) && !log_sep_dien.reading_photo.attached?
      log_sep_dien.reading_photo.attach(io: File.open(sample_photo_path), filename: "cong_to_dien_phong_#{r1.id}.png", content_type: "image/png")
    end
    log_sep_dien.save!
    puts "  Created unconfirmed log for Room #{r1.name} (Điện) with photo"
  end

  if r1 && nuoc_variant
    log_sep_nuoc = ServiceUsageLog.find_or_initialize_by(room: r1, service_variant: nuoc_variant, billing_month: sep_month)
    log_sep_nuoc.assign_attributes(
      service: nuoc_variant.service,
      service_name: nuoc_variant.service.name,
      unit: nuoc_variant.human_unit,
      unit_price: nuoc_variant.fee,
      prev_reading: 58,
      latest_reading: 76,
      usage_quantity: 18,
      start_date: sep_month.beginning_of_month,
      end_date: sep_month.end_of_month,
      is_confirmed: false,
      submitted_by: tenant_user1
    )
    if File.exist?(sample_photo_path) && !log_sep_nuoc.reading_photo.attached?
      log_sep_nuoc.reading_photo.attach(io: File.open(sample_photo_path), filename: "dong_ho_nuoc_phong_#{r1.id}.png", content_type: "image/png")
    end
    log_sep_nuoc.save!
    puts "  Created unconfirmed log for Room #{r1.name} (Nước) with photo"
  end

  # Room 2: Confirmed by landlord
  if r2 && dien_variant
    log_sep_dien2 = ServiceUsageLog.find_or_initialize_by(room: r2, service_variant: dien_variant, billing_month: sep_month)
    log_sep_dien2.assign_attributes(
      service: dien_variant.service,
      service_name: dien_variant.service.name,
      unit: dien_variant.human_unit,
      unit_price: dien_variant.fee,
      prev_reading: 150,
      latest_reading: 280,
      usage_quantity: 130,
      start_date: sep_month.beginning_of_month,
      end_date: sep_month.end_of_month,
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by: landlord,
      submitted_by: landlord
    )
    log_sep_dien2.save!
    puts "  Created confirmed log for Room #{r2.name} (Điện)"
  end

  # Room 3: Non-real-time service log (WiFi)
  if r3 && wifi_variant
    log_sep_wifi = ServiceUsageLog.find_or_initialize_by(room: r3, service_variant: wifi_variant, billing_month: sep_month)
    log_sep_wifi.assign_attributes(
      service: wifi_variant.service,
      service_name: wifi_variant.service.name,
      unit: wifi_variant.human_unit,
      unit_price: wifi_variant.fee,
      prev_reading: 0,
      latest_reading: 1,
      usage_quantity: 1,
      start_date: sep_month.beginning_of_month,
      end_date: sep_month.end_of_month,
      is_confirmed: true,
      confirmed_at: Time.current,
      confirmed_by: landlord,
      submitted_by: landlord
    )
    log_sep_wifi.save!
    puts "  Created fixed fee log for Room #{r3.name} (WiFi)"
  end
end

puts "== Seeding complete! =="
