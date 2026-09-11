import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bank-account-form"
export default class extends Controller {
  static targets = [
    "bankSelect",
    "payosContainer",
    "payosToggle",
    "payosCollapse",
    "unsupportedNotice"
  ]

  static values = {
    supportedBankIds: Array
  }

  connect() {
    this.updateVisibility()
  }

  bankChanged() {
    this.updateVisibility()
  }

  updateVisibility() {
    if (!this.hasBankSelectTarget) return

    const rawValue = this.bankSelectTarget.value
    const selectedBankId = parseInt(rawValue, 10)
    const hasSelection = !isNaN(selectedBankId) && rawValue !== ""
    const isSupported = hasSelection && (this.supportedBankIdsValue || []).includes(selectedBankId)

    // Handle payOS container & inputs
    if (this.hasPayosContainerTarget) {
      if (isSupported) {
        this.payosContainerTarget.classList.remove("d-none")
      } else {
        this.payosContainerTarget.classList.add("d-none")

        // Uncheck payos toggle when switching to an unsupported or blank bank
        if (this.hasPayosToggleTarget && this.payosToggleTarget.checked) {
          this.payosToggleTarget.checked = false
        }

        // Collapse payos details section
        if (this.hasPayosCollapseTarget) {
          this.payosCollapseTarget.classList.remove("show")
          if (typeof bootstrap !== "undefined" && bootstrap.Collapse) {
            const collapseInstance = bootstrap.Collapse.getInstance(this.payosCollapseTarget)
            if (collapseInstance) {
              collapseInstance.hide()
            }
          }
        }
      }
    }

    // Handle unsupported bank notice
    if (this.hasUnsupportedNoticeTarget) {
      if (hasSelection && !isSupported) {
        this.unsupportedNoticeTarget.classList.remove("d-none")
      } else {
        this.unsupportedNoticeTarget.classList.add("d-none")
      }
    }
  }
}
