import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "countDisplay", "selectAllBtn"]

  connect() {
    this.updateCount()
  }

  updateCount() {
    if (!this.hasCountDisplayTarget) return
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked).length
    this.countDisplayTarget.textContent = checkedCount
  }

  toggleAll(event) {
    event.preventDefault()
    const allChecked = this.checkboxTargets.every(cb => cb.checked)
    const newState = !allChecked

    this.checkboxTargets.forEach(cb => {
      if (!cb.disabled) {
        cb.checked = newState
      }
    })

    this.updateCount()
  }

  toggleFloor(event) {
    event.preventDefault()
    const floorContainer = event.currentTarget.closest(".floor-group")
    if (!floorContainer) return

    const checkboxes = floorContainer.querySelectorAll("input[type='checkbox']")
    const allChecked = Array.from(checkboxes).every(cb => cb.checked)
    const newState = !allChecked

    checkboxes.forEach(cb => {
      if (!cb.disabled) {
        cb.checked = newState
      }
    })

    this.updateCount()
  }
}

