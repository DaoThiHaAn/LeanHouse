# frozen_string_literal: true

module ServiceUsageLogsHelper
  def usage_log_confirmation_badge(log)
    if log.is_confirmed?
      content_tag(:span, class: "badge bg-success-subtle text-success border border-success-subtle px-2 py-1 d-inline-flex align-items-center gap-1") do
        concat content_tag(:span, "check_circle", class: "material-symbols-filled fs-6")
        concat " "
        concat t("invoice.status_confirmed")
      end
    else
      content_tag(:span, class: "badge bg-warning-subtle text-warning-emphasis border border-warning-subtle px-2 py-1 d-inline-flex align-items-center gap-1") do
        concat content_tag(:span, "schedule", class: "material-symbols-filled fs-6")
        concat " "
        concat t("invoice.status_unconfirmed")
      end
    end
  end

  def usage_log_billed_badge(log, show_unbilled: false, extra_class: nil)
    if log.billed?
      count = log.respond_to?(:invoices) ? (log.invoices.loaded? ? log.invoices.size : log.invoices.count) : 1
      text = count > 1 ? "#{t('invoice.status_billed')} (#{count})" : t("invoice.status_billed")
      classes = [ "badge bg-info-subtle text-info-emphasis border border-info-subtle px-2 py-1", extra_class ].compact.join(" ")
      content_tag(:span, text, class: classes)
    elsif show_unbilled
      content_tag(:span, t("service_usage_logs.not_billed_yet"), class: "text-secondary small fst-italic")
    end
  end

  def usage_log_confirmed_at(log)
    return unless log.is_confirmed? && log.confirmed_at.present?

    content_tag(:span, class: "text-secondary small d-block mt-1", title: t("service_usage_logs.confirmed_at_label")) do
      concat l(log.confirmed_at, format: :default)
    end
  end

  def usage_log_status_badges(log)
    badges = [
      usage_log_confirmation_badge(log),
      usage_log_billed_badge(log, extra_class: "ms-1")
    ].compact

    timestamp = usage_log_confirmed_at(log)

    safe_join([ safe_join(badges), timestamp ].compact)
  end
  alias_method :usage_log_status_cell, :usage_log_status_badges

  def fixed_tab?(tab = @current_tab)
    tab.to_s == "fixed"
  end

  def real_time_tab?(tab = @current_tab)
    !fixed_tab?(tab)
  end

  def usage_logs_tab_class(tab_name, current_tab = @current_tab)
    current = current_tab.presence || "real_time"
    current.to_s == tab_name.to_s ? "active shadow-sm" : "text-secondary"
  end

  def house_usage_logs_tab_meta(tab = @current_tab)
    if fixed_tab?(tab)
      {
        icon: "lock",
        page_title: t("service_usage_logs.house_tab_fixed"),
        title: t("service_usage_logs.house_fixed_summary_title"),
        subtitle: t("service_usage_logs.house_fixed_summary_subtitle")
      }
    else
      {
        icon: "electric_meter",
        page_title: t("service_usage_logs.house_tab_real_time"),
        title: t("service_usage_logs.house_realtime_summary_title"),
        subtitle: t("service_usage_logs.house_realtime_summary_subtitle")
      }
    end
  end

  def usage_logs_tab_icon(tab = @current_tab)
    fixed_tab?(tab) ? "lock" : "electric_meter"
  end
end
