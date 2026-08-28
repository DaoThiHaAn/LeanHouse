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
end

# Tạo badge tag trạng thái hợp đồng (Còn hiệu lực, Sắp hết hạn, Quá hạn)
# @param status_or_contract [Symbol]
def contract_state_tag(status_contract)
  case status_contract
  when :nearly_due, :"nearly-due"
    content_tag(
      :div,
      t("form.contract.nearly_due"),
      class: "contract-badge badge-nearly-due"
    )
  when :overdue
    content_tag(
      :div,
      t("form.contract.overdue"),
      class: "contract-badge badge-overdue"
    )
  else # :normal, :active
    content_tag(
      :div,
      t("form.contract.normal"),
      class: "contract-badge badge-active"
    )
  end
end
