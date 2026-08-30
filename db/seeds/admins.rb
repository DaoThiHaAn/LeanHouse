puts "  Creating default Admin accounts..."

super_admin = Admin.find_or_initialize_by(email: "admin@leanhouse.vn")
super_admin.assign_attributes(
  fullname: "Hệ Thống Quản Trị",
  password: "Password123!",
  password_confirmation: "Password123!",
  role: "super_admin",
  is_active: true
)
super_admin.save!

support_admin = Admin.find_or_initialize_by(email: "support@leanhouse.vn")
support_admin.assign_attributes(
  fullname: "Nhân Viên Hỗ Trợ",
  password: "Password123!",
  password_confirmation: "Password123!",
  role: "support",
  is_active: true
)
support_admin.save!

puts "  Created Admin: admin@leanhouse.vn / Password123!"
puts "  Created Admin: support@leanhouse.vn / Password123!"
