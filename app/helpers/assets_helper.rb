module AssetsHelper
  # Tạo tag nhãn màu cho tình trạng tài sản
  # @param status_asset [Symbol]
  def asset_status_tag(status_asset)
    case status_asset
    when :damaged
      content_tag(
        :span,
        I18n.t("enums.asset.status.damaged"),
        class: "asset-status-badge badge-damaged fw-medium"
      )
    when :under_repair
      content_tag(
        :span,
        I18n.t("enums.asset.status.under_repair"),
        class: "asset-status-badge badge-under-repair fw-medium"
      )
    else # :normal
      content_tag(
        :span,
        I18n.t("enums.asset.status.normal"),
        class: "asset-status-badge badge-normal fw-medium"
      )
    end
  end

  # Badge with icon and styling for asset status (e.g. admin portal)
  # @param asset_or_status [Asset, String, Symbol, Object]
  def asset_status_badge(asset_or_status)
    status = asset_or_status.respond_to?(:status) ? asset_or_status.status.to_s : asset_or_status.to_s

    icon_name, badge_class = case status
    when "normal"
      [ "check_circle", "bg-success-subtle text-success border border-success-subtle" ]
    when "damaged"
      [ "error", "bg-danger-subtle text-danger border border-danger-subtle" ]
    when "under_repair"
      [ "build", "bg-warning-subtle text-warning border border-warning-subtle" ]
    else
      [ "info", "bg-secondary-subtle text-secondary border border-secondary-subtle" ]
    end

    content_tag(:span, class: "badge #{badge_class} d-inline-flex align-items-center justify-content-center gap-1") do
      concat content_tag(:span, icon_name, class: "material-symbols-outlined fs-6")
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
