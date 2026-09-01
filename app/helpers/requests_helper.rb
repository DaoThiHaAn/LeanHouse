module RequestsHelper
  def request_status_badge(status, size: :sm)
    status_str = status.to_s
    label = I18n.t("enums.request.status.#{status_str}", default: status_str.humanize)

    size_class = (size.to_sym == :lg) ? "badge-lg" : "badge-sm"
    badge_variant = "badge-#{status_str}"

    icon_name = case status_str
    when "pending" then "hourglass_empty"
    when "handling" then "sync"
    when "completed", "approved" then "check_circle"
    when "rejected" then "cancel"
    when "overdue" then "timer_off"
    else "info"
    end

    icon_html = content_tag(:span, icon_name, class: "material-symbols-filled #{size.to_sym == :lg ? 'fs-5' : 'fs-6'} align-middle")

    content_tag(:span, class: "request-status-badge #{badge_variant} #{size_class}") do
      safe_join([ icon_html, content_tag(:span, label) ])
    end
  end

  def request_expiry_badge(request)
    return unless request.pending? && request.requestable_type == "VehicleRequest"

    status = request.expiry_status
    case status
    when :due_today
      content_tag(:span, class: "badge bg-danger text-white d-inline-flex align-items-center gap-1 shadow-xs px-2 py-1 mt-1") do
        safe_join([
          content_tag(:span, "alarm", class: "material-symbols-filled fs-6 warning-pulse"),
          content_tag(:span, I18n.t("request.stats.due_today", default: "Hết hạn hôm nay!"))
        ])
      end
    when :nearly_due
      days = [ request.remaining_expiry_days, 1 ].max
      content_tag(:span, class: "badge bg-warning text-dark d-inline-flex align-items-center gap-1 shadow-xs px-2 py-1 mt-1") do
        safe_join([
          content_tag(:span, "schedule", class: "material-symbols-outlined fs-6"),
          content_tag(:span, I18n.t("request.stats.due_in_days", days: days, default: "Còn #{days} ngày"))
        ])
      end
    when :normal
      days = request.remaining_expiry_days
      content_tag(:span, class: "badge bg-light text-secondary border d-inline-flex align-items-center gap-1 px-2 py-1 mt-1 small") do
        safe_join([
          content_tag(:span, "schedule", class: "material-symbols-outlined fs-6 text-muted"),
          content_tag(:span, I18n.t("request.stats.due_in_days", days: days, default: "Còn #{days} ngày"))
        ])
      end
    end
  end

  def tenant_house_filter_options(houses, current_house)
    options = [ [ t("all"), "" ] ]
    houses.each do |house|
      is_current = current_house.present? && house.id == current_house.id
      label = if is_current
                "#{house.name} (#{t("request.current_house")})"
      else
                house.name
      end
      options << [ label, house.id.to_s ]
    end
    options
  end

  def tenant_year_filter_options(tenant)
    start_year = tenant&.user&.created_at&.year || Date.current.year
    current_year = Date.current.year
    start_year = current_year if start_year > current_year

    [ [ t("all", default: "Tất cả"), "" ] ] + current_year.downto(start_year).map { |y| [ y.to_s, y.to_s ] }
  end

  def landlord_house_filter_options(houses)
    [ [ t("all", default: "Tất cả"), "" ] ] + houses.map { |h| [ h.name, h.id.to_s ] }
  end

  def landlord_year_filter_options(landlord)
    start_year = landlord&.user&.created_at&.year || Date.current.year
    current_year = Date.current.year
    start_year = current_year if start_year > current_year

    [ [ t("all", default: "Tất cả"), "" ] ] + current_year.downto(start_year).map { |y| [ y.to_s, y.to_s ] }
  end
end
