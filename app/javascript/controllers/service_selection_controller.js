import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "checkbox",
    "dropdown",
    "variantInput",
    "variantLabel"
  ]

  connect() {
  }

  toggle(event) {
    const enabled = event.currentTarget.checked

    if (this.hasDropdownTarget) {
      if (enabled) {
        this.dropdownTarget.removeAttribute("disabled")
        this.dropdownTarget.disabled = false
        this.dropdownTarget.classList.remove("disabled")
      } else {
        this.dropdownTarget.setAttribute("disabled", "disabled")
        this.dropdownTarget.disabled = true
        this.dropdownTarget.classList.add("disabled")
        if (typeof bootstrap !== "undefined" && bootstrap.Dropdown) {
          const bsDropdown = bootstrap.Dropdown.getInstance(this.dropdownTarget)
          if (bsDropdown) {
            bsDropdown.hide()
          }
        }
      }
    }

    if (!enabled) {
      this.resetVariant()
    } else {
      if (this.hasVariantInputTarget && !this.variantInputTarget.value) {
        const optionButtons = this.element.querySelectorAll(".dropdown-item[data-variant-id]")
        if (optionButtons.length === 1) {
          const firstOption = optionButtons[0]
          this.variantInputTarget.value = firstOption.dataset.variantId
          if (this.hasVariantLabelTarget) {
            this.variantLabelTarget.innerHTML = firstOption.innerHTML
          }
        }
      }
    }
  }

  selectVariant(event) {
    const button = event.currentTarget
    this.variantInputTarget.value = button.dataset.variantId
    this.variantLabelTarget.innerHTML = button.innerHTML

    if (this.hasDropdownTarget && typeof bootstrap !== "undefined" && bootstrap.Dropdown) {
      const bsDropdown = bootstrap.Dropdown.getInstance(this.dropdownTarget)
      if (bsDropdown) {
        bsDropdown.hide()
      }
    }
  }

  resetVariant() {
    this.variantInputTarget.value = ""
    this.variantLabelTarget.textContent = this.variantLabelTarget.dataset.placeholder
  }
}