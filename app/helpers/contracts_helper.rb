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
