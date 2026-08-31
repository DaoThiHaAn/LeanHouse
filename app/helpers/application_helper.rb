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
    fullname.mb_chars.downcase.titleize.to_s
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
end
