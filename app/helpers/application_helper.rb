module ApplicationHelper
  # Generate syntax for tooltip
  # @param pos [String]: position
  # @param *texts [String / Symbol]: normal string / keys of i18n
  # @param html [Boolean]: convert to html elements
  # Usage:
  # data: {**tooltip(...)}
  def tooltip(pos, *texts, html: false)
    title = texts.map { |text| text.is_a?(Symbol) ? t(text) : text }.join("<br><br>")

    if html
      options = {
        data: {
          controller: "tooltip",
          bs_toggle: "tooltip",
          bs_custom_class: "custom-tooltip",
          bs_placement: pos,
          bs_html: true,
          bs_title: title
        }
      }

      tag.attributes(options).to_s.html_safe
    else
      {
        controller: "tooltip",
        bs_toggle: "tooltip",
        bs_custom_class: "custom-tooltip",
        bs_placement: pos,
        bs_html: true,
        bs_title: title
      }
    end
  end

  def format_money(num)
    "#{number_with_delimiter(num, delimiter: ",")} đ"
  end

  # Format a date as "dd/mm/yyyy" (e.g. 08/09/2026)
  def format_date(date, fallback: "-")
    return fallback if date.blank?

    date.to_date.strftime("%d/%m/%Y")
  end

  # Format a datetime/timestamp as "HH:MM dd/mm/yyyy" (e.g. 14:30 08/09/2026)
  # Set include_seconds: true for "HH:MM:SS dd/mm/yyyy"
  def format_datetime(datetime, include_seconds: false, fallback: "-")
    return fallback if datetime.blank?

    fmt = include_seconds ? "%H:%M:%S %d/%m/%Y" : "%H:%M %d/%m/%Y"
    datetime.strftime(fmt)
  end
  alias_method :format_time, :format_datetime
  alias_method :format_timestamp, :format_datetime

  # Format a month as "mm/yyyy" (e.g. 09/2026)
  def format_month(date_or_time, fallback: "-")
    return fallback if date_or_time.blank?

    date_or_time.strftime("%m/%Y")
  end

  # Render the loading spinner
  def loading_spinner
    content_tag(
      :div,
      class: "d-flex justify-content-center align-items-center p-5"
    ) do
      content_tag(
        :div,
        content_tag(
          :span,
          "#{t("loading")}...",
          class: "visually-hidden"
        ),
        class: "spinner-border text-primary",
        role: "status"
      )
    end
  end

  # Format vietnamese name
  def vn_name(fullname)
    fullname.downcase.titleize
  end

  # Render a polished, consistent back/return navigation link.
  #
  # @param url_or_options [String, Symbol, Hash] Target path, :back (default), or html_options
  # @param text_or_options [String, Symbol, Hash, nil] Label text (symbol resolved via t), or html_options
  # @param text [String, Symbol, nil] Explicit text label (defaults to t('turn_back'))
  # @param icon [String, nil] Material symbol icon name (defaults to "arrow_back")
  # @param class [String, nil] Additional CSS classes
  # @param classes [String, nil] Additional CSS classes
  # @param options [Hash] HTML options passed to link_to
  #
  # Usage:
  #   <%= back_link_to %>
  #   <%= back_link_to landlord_houses_path %>
  #   <%= back_link_to admin_houses_path, t("admin.houses.back_to_list") %>
  #   <%= back_link_to :back, class: "align-self-start" %>
  #   <%= back_link_to { ... } %>
  def back_link_to(*args, text: nil, icon: "arrow_back", classes: nil, extra_classes: nil, **options, &block)
    url = :back
    custom_text = text

    if block_given?
      url = args.first if args.present?
    else
      case args.length
      when 1
        if args.first.is_a?(Hash)
          options.merge!(args.first)
        else
          url = args.first
        end
      when 2
        url = args.first
        custom_text ||= args.second
      end
    end

    extra_class = [ classes, extra_classes, options.delete(:class) ].compact.reject(&:blank?).join(" ")
    merged_class = [ "turn-back link", extra_class ].reject(&:blank?).join(" ")

    if block_given?
      link_to(url, class: merged_class, **options, &block)
    else
      label_text = custom_text.is_a?(Symbol) ? t(custom_text) : (custom_text.presence || t("turn_back", default: "Quay lại"))
      icon_content = icon.present? ? content_tag(:span, icon, class: "material-symbols-outlined turn-back-icon") : nil
      text_content = content_tag(:span, label_text, class: "turn-back-text")

      link_to(url, class: merged_class, **options) do
        safe_join([ icon_content, text_content ].compact)
      end
    end
  end
  alias_method :turn_back_link, :back_link_to

  # Returns the dynamic or configured Webhook URL for payOS
  def payos_webhook_url
    PayosService.webhook_url(defined?(request) ? request : nil)
  end

  # Check whether current webhook URL is running on a local development IP/host
  def payos_local_env?
    url = payos_webhook_url
    url.include?("localhost") || url.include?("127.0.0.1") || url.include?("0.0.0.0")
  end
end
