import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "clearButton"]

  connect() {
    this.updateClearButton()
  }

  debounce() {
    this.updateClearButton()
    clearTimeout(this.timeout)
    // query each 0.8 seconds
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 800)
  }

  changed() {
    this.updateClearButton()
    this.element.requestSubmit()
  }

  clear(event) {
    if (event) {
      event.preventDefault()
    }
    clearTimeout(this.timeout)

    // Clear all text and search inputs in the form
    const inputs = this.element.querySelectorAll("input[type='search'], input[type='text']")
    inputs.forEach(input => {
      input.value = input.dataset.defaultValue || ""
    })

    // Reset all select elements to their default value
    const selects = this.element.querySelectorAll("select")
    selects.forEach(select => {
      if (select.dataset.defaultValue !== undefined) {
        select.value = select.dataset.defaultValue
      } else {
        const hasAll = Array.from(select.options).some(opt => opt.value === "all")
        const hasEmpty = Array.from(select.options).some(opt => opt.value === "")
        if (hasAll) {
          select.value = "all"
        } else if (hasEmpty) {
          select.value = ""
        } else if (select.options.length > 0) {
          select.selectedIndex = 0
        }
      }
    })

    this.updateClearButton()
    this.element.requestSubmit()
  }

  updateClearButton() {
    if (!this.hasClearButtonTarget) return

    const isFiltered = this.checkIfFiltered()

    if (isFiltered) {
      this.clearButtonTarget.classList.remove("d-none")
    } else {
      this.clearButtonTarget.classList.add("d-none")
    }
  }

  checkIfFiltered() {
    // Check all text/search inputs
    const inputs = this.element.querySelectorAll("input[type='search'], input[type='text']")
    for (const input of inputs) {
      const defaultVal = input.dataset.defaultValue || ""
      if (input.value.trim() !== defaultVal) {
        return true
      }
    }

    // Check all selects
    const selects = this.element.querySelectorAll("select")
    for (const select of selects) {
      if (select.dataset.defaultValue !== undefined) {
        if (select.value !== select.dataset.defaultValue) {
          return true
        }
      } else {
        if (select.value !== "all" && select.value !== "") {
          return true
        }
      }
    }

    return false
  }
}