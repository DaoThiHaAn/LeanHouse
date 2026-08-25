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
end
