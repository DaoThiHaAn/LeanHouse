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
    // Determine the corresponding submit button that triggered submission
    const submitter = event?.submitter
    const btn = submitter || (this.hasButtonTarget ? this.buttonTarget : (this.element.tagName === "FORM" ? this.element.querySelector("button[type='submit'], input[type='submit']") : this.element))

    if (btn) {
      this.activeButton = btn

      btn.classList.add("disabled")
      btn.style.pointerEvents = "none"
      setTimeout(() => {
        if (this.activeButton && "disabled" in this.activeButton) {
          this.activeButton.disabled = true
        }
      }, 0)
    }

    // Resolve targets (scoped to the clicked button first if present)
    const textTarget = btn?.querySelector?.("[data-loading-target='text']") || (this.hasTextTarget ? this.textTarget : null)
    const iconTarget = btn?.querySelector?.("[data-loading-target='icon']") || (this.hasIconTarget ? this.iconTarget : null)
    const spinnerTarget = btn?.querySelector?.("[data-loading-target='spinner']") || (this.hasSpinnerTarget ? this.spinnerTarget : null)

    const loadingText = btn?.dataset?.loadingText || (this.hasTextValue ? this.textValue : null)

    if (loadingText) {
      if (textTarget) {
        this.originalText = textTarget.textContent
        textTarget.textContent = loadingText
      } else if (btn && btn.tagName === "INPUT") {
        this.originalText = btn.value
        btn.value = loadingText
      }
    }

    if (iconTarget) {
      iconTarget.classList.add("d-none")
    }

    if (spinnerTarget) {
      spinnerTarget.classList.remove("d-none")
    } else if (btn && btn.tagName === "BUTTON" && !btn.querySelector(".spin")) {
      const spinner = document.createElement("span")
      spinner.className = "material-symbols-outlined spin fs-5"
      spinner.textContent = "progress_activity"
      spinner.dataset.dynamicSpinner = "true"
      btn.appendChild(spinner)
    }

    this.element.classList.add("loading")
  }

  reset() {
    const btn = this.activeButton || (this.hasButtonTarget ? this.buttonTarget : (this.element.tagName === "FORM" ? this.element.querySelector("button[type='submit'], input[type='submit']") : this.element))

    if (btn) {
      if ("disabled" in btn) {
        btn.disabled = false
      }
      btn.classList.remove("disabled")
      btn.style.pointerEvents = ""

      const dynamicSpinner = btn.querySelector?.("[data-dynamic-spinner='true']")
      if (dynamicSpinner) {
        dynamicSpinner.remove()
      }
    }

    const textTarget = btn?.querySelector?.("[data-loading-target='text']") || (this.hasTextTarget ? this.textTarget : null)
    if (this.originalText) {
      if (textTarget) {
        textTarget.textContent = this.originalText
      } else if (btn && btn.tagName === "INPUT") {
        btn.value = this.originalText
      }
      this.originalText = null
    }

    const iconTarget = btn?.querySelector?.("[data-loading-target='icon']") || (this.hasIconTarget ? this.iconTarget : null)
    if (iconTarget) {
      iconTarget.classList.remove("d-none")
    }

    const spinnerTarget = btn?.querySelector?.("[data-loading-target='spinner']") || (this.hasSpinnerTarget ? this.spinnerTarget : null)
    if (spinnerTarget) {
      spinnerTarget.classList.add("d-none")
    }

    this.element.classList.remove("loading")
    this.activeButton = null
  }
}
