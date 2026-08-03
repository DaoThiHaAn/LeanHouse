module ApplicationHelper
  # Generate syntax for tooltip
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
end
