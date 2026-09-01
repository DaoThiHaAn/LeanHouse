import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "monthInput",
    "roomSelect",
    "invoiceTypeSelect",
    "tenantWrapper",
    "tenantSelect"
  ]

  static values = {
    previewUrl: String
  }

  connect() {
    this.toggleTenantSelect()
  }

  toggleTenantSelect() {
    if (!this.hasInvoiceTypeSelectTarget || !this.hasTenantWrapperTarget) return
    const isIndividual = this.invoiceTypeSelectTarget.value === "individual"
    this.tenantWrapperTarget.style.display = isIndividual ? "block" : "none"
  }

  updatePreview() {
    this.toggleTenantSelect()

    const month = this.hasMonthInputTarget ? this.monthInputTarget.value : ""
    const roomId = this.hasRoomSelectTarget ? this.roomSelectTarget.value : ""
    const invoiceType = this.hasInvoiceTypeSelectTarget ? this.invoiceTypeSelectTarget.value : "room"
    const isIndividual = invoiceType === "individual"
    const tenantId = (isIndividual && this.hasTenantSelectTarget) ? this.tenantSelectTarget.value : ""

    if (!this.previewUrlValue || !roomId) return

    const url = new URL(this.previewUrlValue, window.location.origin)
    url.searchParams.set("room_id", roomId)
    url.searchParams.set("month", month)
    url.searchParams.set("invoice_type", invoiceType)
    if (tenantId) {
      url.searchParams.set("tenant_id", tenantId)
    }

    fetch(url.toString(), {
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
      .then(res => res.text())
      .then(html => {
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, "text/html")
        const newFrame = doc.querySelector("turbo-frame#draft_items_form")
        const currentFrame = document.querySelector("turbo-frame#draft_items_form")
        if (newFrame && currentFrame) {
          currentFrame.replaceWith(newFrame)
          setTimeout(() => {
            if (typeof window.recalculateInvoiceTotals === "function") {
              window.recalculateInvoiceTotals()
            }
          }, 50)
        }
      })
      .catch(error => {
        console.error("Failed to update draft invoice preview:", error)
      })
  }
}
