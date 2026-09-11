# frozen_string_literal: true

module InvoicesHelper
  def invoice_status_badge(invoice, check_overdue: true)
    case invoice.status
    when "paid"
      content_tag(:span, class: "invoice-badge invoice-badge-paid") do
        safe_join([
          content_tag(:span, "check_circle", class: "material-symbols-filled fs-6"),
          " ",
          t("invoice.status.paid")
        ])
      end
    when "pending"
      if check_overdue && invoice.overdue?
        content_tag(:span, class: "invoice-badge invoice-badge-overdue") do
          safe_join([
            content_tag(:span, "error", class: "material-symbols-filled fs-6"),
            " ",
            t("invoice.status.overdue")
          ])
        end
      else
        label = check_overdue ? t("invoice.status.waiting_payment") : t("invoice.status.pending")
        content_tag(:span, class: "invoice-badge invoice-badge-pending") do
          safe_join([
            content_tag(:span, "hourglass_top", class: "material-symbols-filled fs-6"),
            " ",
            label
          ])
        end
      end
    when "cancelled"
      content_tag(:span, class: "invoice-badge invoice-badge-cancelled text-decoration-none") do
        safe_join([
          content_tag(:span, "cancel", class: "material-symbols-filled fs-6"),
          " ",
          t("invoice.status.cancelled")
        ])
      end
    end
  end

  def invoice_payment_status_badge(invoice)
    invoice_status_badge(invoice, check_overdue: false)
  end

  def invoice_term_badge(invoice)
    if invoice.overdue?
      content_tag(:span, t("invoice.status.overdue"), class: "invoice-badge invoice-badge-overdue")
    else
      content_tag(:span, t("invoice.status.in_term"), class: "invoice-badge invoice-badge-paid")
    end
  end

  def invoice_header_badges(invoice)
    safe_join([
      invoice_term_badge(invoice),
      invoice_payment_status_badge(invoice)
    ], " ")
  end

  def invoice_type_badge(invoice, show_target: true)
    if invoice.custom?
      label = if show_target && (invoice.tenant || invoice.room)
                "#{t('invoice.badge_custom')}: #{invoice.tenant&.user&.fullname || invoice.room&.title_name}"
      else
                t("invoice.badge_custom")
      end
      content_tag(:span, label, class: "invoice-badge invoice-badge-custom")
    elsif invoice.individual? && invoice.tenant
      label = show_target ? "#{t('invoice.badge_self_pay')}: #{invoice.tenant.user.fullname}" : t("invoice.badge_self_pay")
      content_tag(:span, label, class: "invoice-badge invoice-badge-individual")
    else
      content_tag(:span, t("invoice.badge_representative"), class: "invoice-badge invoice-badge-room")
    end
  end
end
