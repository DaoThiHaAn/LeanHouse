module ApplicationHelper
  # Generate syntax for tooltip
  def tooltip(pos, i18n_key, html = false)
    if html
      options = {
        data: {
          controller: "tooltip",
          bs_toggle: "tooltip",
          bs_custom_class: "custom-tooltip",
          bs_placement: pos,
          bs_title: t(i18n_key)
        }
      }

       tag.attributes(options).to_s.html_safe
    else
      {
        controller: "tooltip",
        bs_toggle: "tooltip",
        bs_custom_class: "custom-tooltip",
        bs_placement: pos,
        bs_title: t(i18n_key) # I18n
      }
    end
  end

  def format_money(num)
    "#{number_with_delimiter(num, delimiter: ",")} đ"
  end
end
