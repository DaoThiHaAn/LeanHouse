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
end
