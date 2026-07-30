import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.updateSelection()
    console.log("Role selector connected")
    console.log("Current hidden value:", this.inputTarget.value)
  }

  select(event) {
    // Update hidden input
    this.inputTarget.value = event.currentTarget.dataset.roleSelectorValue
    console.log("Selected value:", this.inputTarget.value)
    // Refresh UI
    this.updateSelection()
  }

  updateSelection() {
    const selected = this.inputTarget.value

    this.element.querySelectorAll(".role-option").forEach((option) => {
      option.classList.toggle(
        "selected",
        option.dataset.roleSelectorValue === selected
      )
    })

    // Notify other controllers
    this.dispatch("changed", {
      detail: { mode: selected }
    })
  }
}