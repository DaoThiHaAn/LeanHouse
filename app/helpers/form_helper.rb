module FormHelper
  def invalid_class(object, field)
    object.errors[field].any? ? "is-invalid" : ""
  end

  def field_error(object, field)
    return unless object.errors[field].any?

    content_tag :div,
      object.errors[field].first,
      class: "invalid-feedback d-block mt-1"
  end
end
