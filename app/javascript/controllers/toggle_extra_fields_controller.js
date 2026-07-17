import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["extraFields", "checkbox"]

  connect() {
    this.toggle()
  }

  toggle() {
    const checked = this.checkboxTarget.checked

    if (checked) {
      this.extraFieldsTarget.classList.replace("d-none", "d-flex")
    } else {
      this.extraFieldsTarget.classList.replace("d-flex", "d-none")
    }

    // Disable or enable the input fields inside the extra fields container
    this.extraFieldsTarget
      .querySelectorAll("input, select")
      .forEach(field => {
        field.disabled = !checked
      })
  }
}