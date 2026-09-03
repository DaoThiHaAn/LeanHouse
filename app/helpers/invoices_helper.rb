# frozen_string_literal: true

module InvoicesHelper
  def invoice_status_badge(invoice)
    case invoice.status
    when "paid"
      content_tag(:span, class: "invoice-badge invoice-badge-paid") do
        safe_join([
          content_tag(:span, "check_circle", class: "material-symbols-outlined fs-6"),
          " ",
          t("invoice.status.paid")
        ])
      end
    when "pending"
      if invoice.overdue?
        content_tag(:span, class: "invoice-badge invoice-badge-overdue") do
          safe_join([
            content_tag(:span, "error", class: "material-symbols-outlined fs-6"),
            " ",
            t("invoice.status.overdue")
          ])
        end
      else
        content_tag(:span, class: "invoice-badge invoice-badge-pending") do
          safe_join([
            content_tag(:span, "hourglass_top", class: "material-symbols-outlined fs-6"),
            " ",
            t("invoice.status.waiting_payment")
          ])
        end
      end
    when "cancelled"
      content_tag(:span, class: "invoice-badge invoice-badge-cancelled text-decoration-none") do
        safe_join([
          content_tag(:span, "cancel", class: "material-symbols-outlined fs-6"),
          " ",
          t("invoice.status.cancelled")
        ])
      end
    end
  end

  def invoice_type_badge(invoice)
    if invoice.individual? && invoice.tenant
      content_tag(:span, "#{t('invoice.mode_individual')}: #{invoice.tenant.user.fullname}", class: "invoice-badge invoice-badge-individual")
    else
      content_tag(:span, t("invoice.mode_room"), class: "invoice-badge invoice-badge-room")
    end
  end
end
