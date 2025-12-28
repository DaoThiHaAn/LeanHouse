module NavHelper
  def display_avatar
    if current_user.avatar.attached?
      image_tag current_user.avatar_thumb, alt: "Avatar"
    else
      name = ERB::Util.url_encode(current_user.fullname)
      image_tag "https://ui-avatars.com/api/?background=1F6274&name=#{name}&color=ffffff&bold=true&rounded=true&size=128", alt: "Avatar", class: "nav-avatar"
    end
  end


  def get_role
    return t("common.role.landlord") if current_user.role == "landlord"
    return t("common.role.tenant") if current_user.role == "tenant"
    t("common.role.admin")
  end


  def nav_item(real_text, label, word: nil, path: nil, icon: nil, is_img: false, img_src: nil, img_active_src: nil)
    li_classes = [ "nav-item custom d-lg-flex align-items-center align-self-center" ]
    a_classes  = [ "nav-link d-flex align-items-center px-2 flex-wrap justify-content-center" ]

    is_current_page = word.present? ? request.path.include?(word) :current_page?(path)
    if is_current_page
      li_classes << "active"
      a_classes << "fw-bold active" # keep Bootstrap behavior for <a>
    end

    content_tag :li, class: li_classes.join(" ") do
      link_to path, class: a_classes.join(" "),
                  aria: (is_current_page ? { current: "page" } : {}) do
        # decide what to show: image or icon
        icon_or_img =
          if is_img
            is_current_page ? image_tag(img_active_src, class: "me-1 icon-img", alt: label) : image_tag(img_src, class: "me-1 icon-img", alt: label)
          elsif icon.present?
                          content_tag(:span, icon, class: "material-symbols-filled me-1")
          end

        safe_join([ icon_or_img, real_text ].compact)
      end
    end
  end


  def format_name(full_name)
    parts = full_name.strip.split(/\s+/)

    return full_name if parts.length < 2

    first_name = parts.first
    last_name  = parts.last
    middle     = parts[1..-2]

    middle_initials = middle.map { |name| "#{name[0].upcase}." }.join

    "#{first_name} #{middle_initials} #{last_name}"
  end
end
