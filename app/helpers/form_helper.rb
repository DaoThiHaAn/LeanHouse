module FormHelper
  def invalid_class(object, field)
    object.errors[field].any? ? "is-invalid" : ""
  end

  def field_error(object, field, classes: "mt-1")
    return unless object.errors[field].any?

    content_tag :div, class: "invalid-feedback d-block #{classes}" do
      safe_join(
        object.errors[field].map do |message|
          content_tag(:p, message)
        end
      )
    end
  end

  # Default-classes: field-info d-flex align-items-center
  def field_info(messages, extra_classes: "", icon: "info")
    messages = Array(messages)

    content_tag :div,
                class: "field-info d-flex align-items-start #{extra_classes}".strip do
      safe_join([
        content_tag(:div, icon, class: "icon material-symbols-outlined"),
        content_tag(:div, class: "d-flex flex-column gap-1") do
          safe_join(
            messages.map { |message| content_tag(:small, message) }
          )
        end
      ])
    end
  end

  def field_hint(message = nil, classes: "", &block)
    content = block_given? ? capture(&block) : message

    content_tag :small, class: "text-muted w-100 d-flex align-items-center mt-2 ms-1 gap-2 #{classes}".strip do
      safe_join([
        content_tag(:span, "info", class: "material-symbols-outlined fs-6 flex-shrink-0"),
        content_tag(:div, content, class: "w-100")
      ])
    end
  end

  # Display the hint for the capacity of the room in the edit form
  def room_capacity_hint(house, room)
    if house.bed?
      field_hint do
        safe_join([
          t("form.room.bed_mode_capacity_hint"),
          " ",
          link_to(t("form.bed.mng"), landlord_house_beds_path(house), data: { turbo_frame: "_top" }, class: "d-inline-block fw-bold")
        ])
      end
    elsif room.tenants_count > 0
      min_slots = [ room.tenants_count, 1 ].max
      field_hint(t("form.room.occupied_capacity_hint", count: room.tenants_count, min: min_slots))
    else
      field_hint(t("form.room.empty_capacity_hint"))
    end
  end

  def bed_field_title(house)
    return t("form.room.max_tenants_count") if house.room?
    t("form.room.beds_count")
  end
end
