module ApplicationHelper
  def nav_item(real_text, label, path, icon: nil)
    li_classes = [ "nav-item custom d-lg-flex align-items-center align-self-center" ]
    a_classes  = [ "nav-link d-flex align-items-center px-2" ]

    if current_page?(path)
      li_classes << "active"
      a_classes << "fw-bold active" # keep Bootstrap behavior for <a>
    end

    content_tag :li, class: li_classes.join(" ") do
      link_to path, class: a_classes.join(" "),
                  aria: (current_page?(path) ? { current: "page" } : {}) do
        # prepend icon if given
        safe_join([
          icon.present? ? content_tag(:span, icon, class: "material-symbols-filled me-1") : nil,
          real_text
        ].compact)
      end
    end
  end
end
