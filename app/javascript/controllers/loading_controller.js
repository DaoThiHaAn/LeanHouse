import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "text", "spinner", "icon"]
  static values = {
    text: String
  }

  submit() {
    if (!this.element.checkValidity()) return

    this.buttonTarget.disabled = true

    if (this.hasTextValue) {
      this.textTarget.textContent = this.textValue
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.add("d-none")
    }

    this.spinnerTarget.classList.remove("d-none")
    this.element.classList.add("loading")
  }
}
