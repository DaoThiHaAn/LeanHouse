import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["extraFields", "checkbox"]

  connect() {
    // Ensure correct state on page load (edit form)
    this.toggle()
    console.log("ToggleExtraFieldsController connected")
  }

  toggle() {
    if (this.checkboxTarget.checked) {
      this.extraFieldsTarget.classList.replace("d-none", "d-flex")
    } else {
      this.extraFieldsTarget.classList.replace("d-flex", "d-none")
    }
  }
}
