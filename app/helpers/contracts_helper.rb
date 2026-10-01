module ContractsHelper
  # Generate the label for contract's due date or temporary residence registration's due date
  # @param due_date_type [Symbol] - :overdue, :normal, :nearly_due
  def due_status_icon_label(due_date_type)
    case due_date_type

    when :overdue
      image_tag(
        "overdue.png",
        alt: "Overdue icon",
        title: t("form.contract.overdue"),
        width: "25px"
      )

    when :nearly_due
      image_tag(
        "nearly-due.png",
        alt: "Nearly due icon",
        title: t("form.contract.nearly_due"),
        width: "25px"
      )

    when :normal
      image_tag(
        "normal.png",
        alt: "Normal icon",
        title: t("form.contract.normal"),
        width: "25px"
      )
    end
  end

  # Tạo badge tag trạng thái hợp đồng (Còn hiệu lực, Sắp hết hạn, Quá hạn, Đã kết thúc)
  # @param status_or_contract [Contract, Symbol, String]
  # @param style [Symbol] :custom (default .contract-badge) or :badge (Bootstrap .badge)
  def contract_state_tag(status_or_contract, style: :custom)
    status = if status_or_contract.respond_to?(:due_status)
               status_or_contract.due_status
    else
               status_or_contract.to_s.tr("-", "_").to_sym
    end

    if style == :badge
      badge_class, label_key = case status
      when :finished
                                 [ "badge bg-secondary", "admin.contracts.state_finished" ]
      when :overdue
                                 [ "badge bg-danger", "admin.contracts.state_overdue" ]
      when :nearly_due
                                 [ "badge bg-warning text-dark", "admin.contracts.state_nearly_due" ]
      else
                                 [ "badge bg-success", "admin.contracts.state_active" ]
      end
      content_tag(:span, t(label_key, default: t("form.contract.#{status}")), class: badge_class)
    else
      css_class, label_key = case status
      when :finished
                               [ "contract-badge badge-finished", "form.contract.finished" ]
      when :nearly_due
                               [ "contract-badge badge-nearly-due", "form.contract.nearly_due" ]
      when :overdue
                               [ "contract-badge badge-overdue", "form.contract.overdue" ]
      else
                               [ "contract-badge badge-active", "form.contract.normal" ]
      end
      content_tag(:div, t(label_key, default: "Đã kết thúc"), class: css_class)
    end
  end
end
