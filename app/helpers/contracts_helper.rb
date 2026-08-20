module ContractsHelper
  # Generate the label for contract's due date or temporary residence registration's due date
  # @param contract_due_date_type [Symbol]
  def due_status_label(contract_due_date_type)
    case contract_due_date_type
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
    end
  end
end
