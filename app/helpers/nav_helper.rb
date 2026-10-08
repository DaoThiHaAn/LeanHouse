module NavHelper
  def display_avatar(user = nil, default_anomy_size: 128)
    user ||= if respond_to?(:controller_path) && controller_path.to_s.start_with?("admin_portal")
      respond_to?(:current_admin) ? current_admin : nil
    else
      respond_to?(:current_user) && current_user.present? ? current_user : (respond_to?(:current_admin) ? current_admin : nil)
    end
    return "" unless user

    if user.respond_to?(:avatar) && user.avatar.attached?
      image_tag user.avatar_thumb, alt: "Avatar", width: "40px"
    else
      name = ERB::Util.url_encode(user.fullname)
      image_tag "https://ui-avatars.com/api/?background=1F6274&name=#{name}&color=ffffff&bold=true&rounded=true&size=#{default_anomy_size}", alt: "Avatar", class: "nav-avatar"
    end
  end

  def get_role(user = nil)
    user ||= if respond_to?(:controller_path) && controller_path.to_s.start_with?("admin_portal")
      respond_to?(:current_admin) ? current_admin : nil
    else
      respond_to?(:current_user) && current_user.present? ? current_user : (respond_to?(:current_admin) ? current_admin : nil)
    end

    return "" unless user

    if user.is_a?(Admin)
      return t("enums.admin.roles.#{user.role}", default: user.role.titleize)
    end

    if user.respond_to?(:role)
      return t("role.landlord") if user.role == "landlord"
      return t("role.tenant") if user.role == "tenant"
    end

    t("role.admin", default: "Quản trị viên")
  end


  def nav_item(real_text, label, word: nil, path: nil, icon: nil, is_img: false, img_src: nil, img_active_src: nil, badge: nil)
    li_classes = [ "flex-shrink-0 nav-item custom d-lg-flex align-items-center m-1" ]
    a_classes  = [ "nav-link text-center d-flex align-items-center px-2 flex-wrap justify-content-md-center" ]

    is_current_page = word.present? ? request.path.include?(word) : current_page?(path)
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

        safe_join([ icon_or_img, real_text, badge ].compact)
      end
    end
  end

  # @params full_name [String]
  # @return formatted name [String]: First_name M.I.D... Last_name
  def format_name(full_name)
    # Format: Lastname M. Firstname
    parts = full_name.strip.split(/\s+/)

    return full_name if parts.length < 2

    first_name = parts.first
    last_name  = parts.last
    middle     = parts[1..-2]

    middle_initials = middle.map { |name| "#{name[0].upcase}." }.join

    "#{first_name} #{middle_initials} #{last_name}"
  end

  def noti_count(num)
    return "99+" if num > 99
    num
  end

  def pending_requests_count
    @pending_requests_count ||= Request.pending.count
  end

  def landlord_pending_requests_count
    return 0 unless current_user&.landlord? && current_user.landlord

    @landlord_pending_requests_count ||= current_user.landlord.requests.pending.count
  end

  def pending_issue_reports_count
    @pending_issue_reports_count ||= IssueReport.pending.count
  end
end
