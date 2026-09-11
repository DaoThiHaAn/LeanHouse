import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio", "customInputWrapper", "customInput", "systemPreview", "livePreview"]

  connect() {
    this.updateState()
    this.boundSubmitHandler = this.handleSubmit.bind(this)
    this.form = this.element.closest("form")
    if (this.form) {
      this.form.addEventListener("submit", this.boundSubmitHandler)
    }
  }

  disconnect() {
    if (this.form && this.boundSubmitHandler) {
      this.form.removeEventListener("submit", this.boundSubmitHandler)
    }
  }

  modeChanged() {
    this.updateState()
  }

  // Live update without mutating input.value (mutating input.value during typing breaks Vietnamese IMEs like IBus/Unikey)
  liveUpdate() {
    if (!this.hasCustomInputTarget) return
    const raw = this.customInputTarget.value
    const cleaned = this.clean(raw, false)

    if (this.hasLivePreviewTarget) {
      if (cleaned.length > 0 && cleaned !== raw.toUpperCase()) {
        this.livePreviewTarget.textContent = `→ ${cleaned}`
        this.livePreviewTarget.classList.remove("d-none")
      } else {
        this.livePreviewTarget.textContent = ""
        this.livePreviewTarget.classList.add("d-none")
      }
    }
  }

  // Safe to sanitize when user completes editing (blur / change)
  sanitizeField() {
    if (!this.hasCustomInputTarget) return
    const raw = this.customInputTarget.value
    const cleaned = this.clean(raw, true)
    if (raw !== cleaned) {
      this.customInputTarget.value = cleaned
      // Update character counter if present
      this.customInputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
    if (this.hasLivePreviewTarget) {
      this.livePreviewTarget.textContent = ""
      this.livePreviewTarget.classList.add("d-none")
    }
  }

  // Safe to sanitize after paste completes
  onPaste() {
    setTimeout(() => {
      this.sanitizeField()
    }, 0)
  }

  handleSubmit() {
    const selectedRadio = this.radioTargets.find(r => r.checked)
    if (selectedRadio && selectedRadio.value === "custom") {
      this.sanitizeField()
    }
  }

  clean(text, isFinal = false) {
    if (!text) return ""
    let res = text
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[đĐ]/g, "D")
      .replace(/[^A-Za-z0-9 -]/g, "")
      .toUpperCase()
      .slice(0, 50)

    if (isFinal) {
      res = res.replace(/\s+/g, " ").trim()
    }
    return res
  }

  updateState() {
    const selectedRadio = this.radioTargets.find(r => r.checked)
    const mode = selectedRadio ? selectedRadio.value : "system"

    if (this.hasCustomInputWrapperTarget) {
      this.customInputWrapperTarget.classList.toggle("d-none", mode !== "custom")
    }

    if (this.hasSystemPreviewTarget) {
      this.systemPreviewTarget.classList.toggle("d-none", mode !== "system")
    }

    if (this.hasCustomInputTarget) {
      this.customInputTarget.disabled = (mode !== "custom")
      if (mode === "custom") {
        this.customInputTarget.focus()
        this.liveUpdate()
      }
    }
  }
}
