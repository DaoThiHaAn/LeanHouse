module RequestsHelper
  def request_status_badge(status)
    status_str = status.to_s
    label = I18n.t("enums.request.status.#{status_str}", default: status_str.humanize)

    badge_class = case status_str
    when "pending"
      "bg-warning text-dark"
    when "handling"
      "bg-primary text-white"
    when "completed"
      "bg-success text-white"
    when "approved"
      "bg-success text-white"
    when "rejected"
      "bg-danger text-white"
    when "overdue"
      "bg-secondary text-white"
    else
      "bg-light text-dark border"
    end

    content_tag(:span, label, class: "badge #{badge_class} fw-medium px-2 py-1")
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
