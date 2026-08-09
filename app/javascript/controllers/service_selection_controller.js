import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "checkbox",
    "dropdown",
    "variantInput",
    "variantLabel"
  ]

  connect() {
    console.log("Service selection connected!")
  }

  toggle(event) {
    const enabled = event.currentTarget.checked

    this.dropdownTarget.disabled = !enabled

    if (!enabled) {
      this.resetVariant()
    }
  }

  selectVariant(event) {
    const button = event.currentTarget
    this.variantInputTarget.value = button.dataset.variantId
    this.variantLabelTarget.innerHTML = button.innerHTML
  }

  resetVariant() {
    this.variantInputTarget.value = ""
    this.variantLabelTarget.textContent = this.variantLabelTarget.dataset.placeholder
  }
}