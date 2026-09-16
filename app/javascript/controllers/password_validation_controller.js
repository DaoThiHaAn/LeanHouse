import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "rule"]

  connect() {
    this.touched = false
    this.boundReset = () => this.reset()

    const form = this.element.closest("form")
    if (form) {
      form.addEventListener("reset", this.boundReset)
    }

    // Attach listeners directly to inputTarget if present
    if (this.hasInputTarget) {
      this.boundInput = () => this.validate()
      this.boundBlur = () => this.onBlur()
      this.boundFocus = () => this.onFocus()

      this.inputTarget.addEventListener("input", this.boundInput)
      this.inputTarget.addEventListener("blur", this.boundBlur)
      this.inputTarget.addEventListener("focus", this.boundFocus)

      // Initial validation if pre-filled (e.g. browser autofill or server re-render)
      if (this.inputTarget.value) {
        this.validate()
      }
    }
  }

  disconnect() {
    const form = this.element.closest("form")
    if (form && this.boundReset) {
      form.removeEventListener("reset", this.boundReset)
    }

    if (this.hasInputTarget) {
      if (this.boundInput) this.inputTarget.removeEventListener("input", this.boundInput)
      if (this.boundBlur) this.inputTarget.removeEventListener("blur", this.boundBlur)
      if (this.boundFocus) this.inputTarget.removeEventListener("focus", this.boundFocus)
    }
  }

  reset() {
    this.touched = false
    setTimeout(() => {
      this.validate()
    }, 10)
  }

  onBlur() {
    if (!this.hasInputTarget) return
    if (this.inputTarget.value.length > 0) {
      this.touched = true
    }
    this.validate()
  }

  onFocus() {
    this.validate()
  }

  validate() {
    if (!this.hasInputTarget) return

    const value = this.inputTarget.value || ""
    const isEmpty = value.length === 0

    const checks = {
      length: value.length >= 8 && value.length <= 72,
      letter: /[a-zA-Z]/.test(value),
      number: /\d/.test(value)
    }

    let allSatisfied = !isEmpty

    this.ruleTargets.forEach(ruleEl => {
      const ruleType = ruleEl.dataset.rule
      const isSatisfied = !!checks[ruleType]

      if (!isSatisfied) {
        allSatisfied = false
      }

      const iconEl = ruleEl.querySelector("[data-password-validation-target='icon']") ||
                     ruleEl.querySelector(".pw-rule-icon")

      if (isEmpty) {
        ruleEl.classList.remove("is-satisfied", "is-invalid")
        if (iconEl) iconEl.textContent = "radio_button_unchecked"
      } else if (isSatisfied) {
        ruleEl.classList.add("is-satisfied")
        ruleEl.classList.remove("is-invalid")
        if (iconEl) iconEl.textContent = "check_circle"
      } else {
        ruleEl.classList.remove("is-satisfied")
        if (this.touched) {
          ruleEl.classList.add("is-invalid")
          if (iconEl) iconEl.textContent = "cancel"
        } else {
          ruleEl.classList.remove("is-invalid")
          if (iconEl) iconEl.textContent = "radio_button_unchecked"
        }
      }
    })

    // Update input state and accessibility
    if (isEmpty) {
      this.inputTarget.classList.remove("pw-valid", "pw-invalid")
      this.inputTarget.removeAttribute("aria-invalid")
    } else if (allSatisfied) {
      this.inputTarget.classList.add("pw-valid")
      this.inputTarget.classList.remove("pw-invalid")
      this.inputTarget.setAttribute("aria-invalid", "false")
    } else {
      this.inputTarget.classList.remove("pw-valid")
      if (this.touched) {
        this.inputTarget.classList.add("pw-invalid")
        this.inputTarget.setAttribute("aria-invalid", "true")
      } else {
        this.inputTarget.classList.remove("pw-invalid")
        this.inputTarget.removeAttribute("aria-invalid")
      }
    }
  }
}
