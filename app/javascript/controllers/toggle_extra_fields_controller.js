import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["extraFields", "checkbox"]

  connect() {
    this.boundReset = () => {
      setTimeout(() => this.toggle(), 10)
    }
    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("reset", this.boundReset)
    }

    this.toggle()
  }

  disconnect() {
    const form = this.element.closest("form")
    if (form && this.boundReset) {
      form.removeEventListener("reset", this.boundReset)
    }
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