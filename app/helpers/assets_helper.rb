module AssetsHelper
  # Tạo tag nhãn màu cho tình trạng tài sản (hỗ trợ Symbol, String, hoặc Asset model)
  # @param status_asset [Asset, String, Symbol, Object]
  def asset_status_tag(status_asset)
    asset_status_badge(status_asset)
  end

  # Badge with icon and styling for asset status (admin portal & landlord portal)
  # @param asset_or_status [Asset, String, Symbol, Object]
  def asset_status_badge(asset_or_status)
    status = asset_or_status.respond_to?(:status) ? asset_or_status.status.to_s : asset_or_status.to_s

    icon_name, badge_class = case status
    when "normal"
      [ "check_circle", "bg-success-subtle text-success-emphasis border border-success-subtle" ]
    when "damaged"
      [ "error", "bg-danger-subtle text-danger-emphasis border border-danger-subtle" ]
    when "under_repair"
      [ "build", "bg-warning-subtle text-warning-emphasis border border-warning-subtle" ]
    else
      [ "info", "bg-secondary-subtle text-secondary-emphasis border border-secondary-subtle" ]
    end

    content_tag(:span, class: "badge #{badge_class} rounded-2 px-2.5 py-1 d-inline-flex align-items-center justify-content-center gap-1 fw-medium shadow-none") do
      concat content_tag(:span, icon_name, class: "material-symbols-filled fs-6", aria: { hidden: true })
      concat content_tag(:span, I18n.t("enums.asset.status.#{status}", default: status.humanize))
    end
  end

  # Badge for asset maintenance cost
  # @param cost_or_logs [Numeric, Enumerable]
  def asset_maintenance_cost_badge(cost_or_logs)
    cost = cost_or_logs.respond_to?(:sum) ? cost_or_logs.sum(&:cost) : cost_or_logs
    content_tag(:span, format_money(cost), class: "badge bg-primary-subtle text-primary border border-primary-subtle d-inline-flex align-items-center justify-content-center")
  end
end
