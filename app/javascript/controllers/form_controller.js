import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "charCount"]

  connect() {
    this.update()
    console.log("FormController connected")
  }

  // char counter
  update() {
    const value = this.inputTarget.value || ""
    const length = value.length
    const max = this.maxLength()

    this.charCountTarget.textContent = max
      ? `${length}/${max}`
      : length
  }

  maxLength() {
    return this.inputTarget.getAttribute("maxlength")
  }

  // toggle password visibility
  togglePasswordVisibility(event) {
    const passwordInput = this.inputTarget
    const toggleIcon = event.currentTarget

    if (passwordInput.type === "password") {
      passwordInput.type = "text"
      toggleIcon.textContent = "visibility_off"
    } else {
      passwordInput.type = "password"
      toggleIcon.textContent = "visibility"
    }
  }
}
