module FormHelper
  def invalid_class(object, field)
    object.errors[field].any? ? "is-invalid" : ""
  end

  def field_error(object, field)
    return unless object.errors[field].any?

    content_tag :div, class: "invalid-feedback d-block mt-1" do
      safe_join(
        object.errors[field].map do |message|
          content_tag(:div, message)
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
end
