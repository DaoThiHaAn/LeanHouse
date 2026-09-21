import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "radio",
    "customInputWrapper",
    "customInput",
    "systemPreview",
    "livePreview",
    "payosNotice",
    "optionsContainer",
    "bankSelect"
  ]

  connect() {
    this.bankSelect = this.findBankSelect()
    if (this.bankSelect) {
      this.boundBankChangeHandler = this.bankAccountChanged.bind(this)
      this.bankSelect.addEventListener("change", this.boundBankChangeHandler)
    }

    this.boundPageshowHandler = this.handlePageShow.bind(this)
    window.addEventListener("pageshow", this.boundPageshowHandler)

    this.boundSubmitHandler = this.handleSubmit.bind(this)
    this.form = this.element.closest("form")
    if (this.form) {
      this.form.addEventListener("submit", this.boundSubmitHandler)
    }

    // Evaluate state immediately
    this.updateState()

    // Re-check shortly after connect in case browser autofill / bfcache restores form state asynchronously on reload
    this.autofillTimeout = setTimeout(() => this.updateState(), 50)
  }

  disconnect() {
    if (this.autofillTimeout) {
      clearTimeout(this.autofillTimeout)
    }
    if (this.bankSelect && this.boundBankChangeHandler) {
      this.bankSelect.removeEventListener("change", this.boundBankChangeHandler)
    }
    if (this.boundPageshowHandler) {
      window.removeEventListener("pageshow", this.boundPageshowHandler)
    }
    if (this.form && this.boundSubmitHandler) {
      this.form.removeEventListener("submit", this.boundSubmitHandler)
    }
  }

  findBankSelect() {
    if (this.hasBankSelectTarget) return this.bankSelectTarget
    const form = this.element.closest("form")
    if (form) {
      const select = form.querySelector('select[name$="[bank_account_id]"], select[name="bank_account_id"], select[data-transfer-note-bank-select]')
      if (select) return select
    }
    return document.querySelector('select[name$="[bank_account_id]"], select[name="bank_account_id"], select[data-transfer-note-bank-select]')
  }

  isPayosSelected() {
    if (!this.bankSelect || !this.bankSelect.isConnected) {
      this.bankSelect = this.findBankSelect()
    }
    if (!this.bankSelect || this.bankSelect.selectedIndex < 0) return false
    const selectedOption = this.bankSelect.options[this.bankSelect.selectedIndex]
    return selectedOption ? selectedOption.dataset.payos === "true" : false
  }

  handlePageShow() {
    this.updateState()
  }

  bankAccountChanged() {
    this.updateState()
  }

  modeChanged() {
    this.updateState()
    const selectedRadio = this.radioTargets.find(r => r.checked)
    if (selectedRadio && selectedRadio.value === "custom" && this.hasCustomInputTarget) {
      this.customInputTarget.focus()
    }
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
    if (this.isPayosSelected()) return

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
    const isPayos = this.isPayosSelected()

    if (this.hasPayosNoticeTarget) {
      this.payosNoticeTarget.classList.toggle("d-none", !isPayos)
    }

    if (this.hasOptionsContainerTarget) {
      this.optionsContainerTarget.classList.toggle("d-none", isPayos)
    }

    if (isPayos) {
      // Disable radio buttons and custom input so they don't submit conflicting values
      this.radioTargets.forEach(r => { r.disabled = true })
      if (this.hasCustomInputTarget) {
        this.customInputTarget.disabled = true
      }
      return
    }

    // Re-enable radio buttons for standard bank account
    this.radioTargets.forEach(r => { r.disabled = false })

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
        this.liveUpdate()
      }
    }
  }
}
