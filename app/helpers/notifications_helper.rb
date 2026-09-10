module NotificationsHelper
  def notification_level_badge(level)
    lvl = level.to_s.presence_in(%w[info warning urgent]) || "info"

    icon_name, badge_class, label_key =
      case lvl
      when "urgent"
        [ "error", "bg-danger-subtle text-danger border border-danger-subtle", "admin.notifications.levels.urgent" ]
      when "warning"
        [ "warning", "bg-warning-subtle text-warning-emphasis border border-warning-subtle", "admin.notifications.levels.warning" ]
      else
        [ "info", "bg-info-subtle text-info-emphasis border border-info-subtle", "admin.notifications.levels.info" ]
      end

    content_tag(:span, class: "badge #{badge_class} px-2 py-1 d-inline-flex align-items-center gap-1") do
      concat content_tag(:span, icon_name, class: "material-symbols-outlined fs-6")
      concat content_tag(:span, t(label_key))
    end
  end

  def notification_audience_badge(audience)
    aud = audience.to_s.presence_in(%w[all landlords tenants]) || "all"

    badge_class, label_key =
      case aud
      when "landlords"
        [ "bg-primary-subtle text-primary border border-primary-subtle", "admin.notifications.audience.landlords" ]
      when "tenants"
        [ "bg-success-subtle text-success border border-success-subtle", "admin.notifications.audience.tenants" ]
      else
        [ "bg-secondary-subtle text-secondary-emphasis border", "admin.notifications.audience.all" ]
      end

    content_tag(:span, t(label_key), class: "badge #{badge_class} px-2 py-1")
  end
end
