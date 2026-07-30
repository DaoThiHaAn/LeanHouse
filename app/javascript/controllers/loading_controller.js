import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "text", "spinner"]
  static values = {
    text: String
  }

  submit() {
    if (!this.element.checkValidity()) return

    this.buttonTarget.disabled = true

    if (this.hasTextValue) {
      this.textTarget.textContent = this.textValue
    }

    this.spinnerTarget.classList.remove("d-none")
    this.element.classList.add("loading")
  }
}