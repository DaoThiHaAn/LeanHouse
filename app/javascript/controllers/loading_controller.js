import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "text", "spinner", "icon"]
  static values = {
    text: String
  }

  connect() {
    this.boundReset = () => this.reset()
    document.addEventListener("turbo:frame-load", this.boundReset)
    document.addEventListener("turbo:submit-end", this.boundReset)
  }

  disconnect() {
    if (this.boundReset) {
      document.removeEventListener("turbo:frame-load", this.boundReset)
      document.removeEventListener("turbo:submit-end", this.boundReset)
    }
  }

  submit(event) {
    if (this.element.checkValidity && !this.element.checkValidity()) return
    this.start(event)
  }

  start(event) {
    const btn = this.hasButtonTarget ? this.buttonTarget : this.element

    if (btn) {
      if ("disabled" in btn) {
        btn.disabled = true
      }
      btn.classList.add("disabled")
      btn.style.pointerEvents = "none"
    }

    if (this.hasTextValue && this.hasTextTarget) {
      this.originalText = this.textTarget.textContent
      this.textTarget.textContent = this.textValue
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.add("d-none")
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("d-none")
    }

    this.element.classList.add("loading")
  }

  reset() {
    const btn = this.hasButtonTarget ? this.buttonTarget : this.element

    if (btn) {
      if ("disabled" in btn) {
        btn.disabled = false
      }
      btn.classList.remove("disabled")
      btn.style.pointerEvents = ""
    }

    if (this.originalText && this.hasTextTarget) {
      this.textTarget.textContent = this.originalText
      this.originalText = null
    }

    if (this.hasIconTarget) {
      this.iconTarget.classList.remove("d-none")
    }

    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("d-none")
    }

    this.element.classList.remove("loading")
  }
}
