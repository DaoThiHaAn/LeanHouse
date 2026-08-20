module ApplicationHelper
  # Generate syntax for tooltip
  # @param pos [String]: position
  # @param *i18n_keys [String]: keys of i18n
  # @param html [Boolean]: convert to html elements
  # Usage:
  # data: {**tooltip(...)}
  def tooltip(pos, *i18n_keys, html: false)
    title = i18n_keys.map { |key| t(key) }.join("<br><br>")

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
end
