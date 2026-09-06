module ServicesHelper
  def service_calculation_type_badge(variant)
    if variant.is_real_time?
      content_tag(:span, class: "badge bg-info-subtle text-info border border-info-subtle d-inline-flex align-items-center gap-1") do
        concat content_tag(:span, "speed", class: "material-symbols-outlined fs-6")
        concat content_tag(:span, t("admin.services.metered"))
      end
    else
      content_tag(:span, class: "badge bg-secondary-subtle text-secondary border border-secondary-subtle d-inline-flex align-items-center gap-1") do
        concat content_tag(:span, "lock", class: "material-symbols-outlined fs-6")
        concat content_tag(:span, t("admin.services.fixed"))
      end
    end
  end
  alias_method :service_variant_type_badge, :service_calculation_type_badge

  def fixed_service_applied_quantity(room, variant, vehicle_count: nil)
    case variant.unit.to_sym
    when :per_room, :per_month
      1.0
    when :per_person
      room.tenants_count.to_f
    when :per_item
      (vehicle_count || room.house.vehicles.where(tenant_id: room.tenants.pluck(:id)).count).to_f
    else
      1.0
    end
  end

  def fixed_service_quantity_display(room, variant, vehicle_count: nil)
    case variant.unit.to_sym
    when :per_room
      t("service_usage_logs.per_room_unit", default: "1 phòng")
    when :per_month
      t("service_usage_logs.per_month_unit", default: "1 tháng")
    when :per_person
      "#{room.tenants_count} #{variant.human_unit} (#{t('service_usage_logs.based_on_tenants', default: 'theo số khách đang ở')})"
    when :per_item
      v_count = vehicle_count || room.house.vehicles.where(tenant_id: room.tenants.pluck(:id)).count
      "#{v_count} #{variant.human_unit} (#{t('service_usage_logs.based_on_vehicles', default: 'theo số xe đăng ký')})"
    else
      "1 #{variant.human_unit}"
    end
  end
end
