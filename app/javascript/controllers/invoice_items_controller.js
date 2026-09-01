import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "table",
    "additionContainer",
    "discountContainer",
    "subtotalSummary",
    "additionSummary",
    "discountSummary",
    "totalSummary"
  ]

  static values = {
    additionPlaceholder: { type: String, default: "Phụ phí phát sinh" },
    discountPlaceholder: { type: String, default: "Giảm trừ / Khuyến mãi" },
    deleteText: { type: String, default: "Xóa dòng" },
    unitOptions: { type: Array, default: [] }
  }

  connect() {
    this.recalculate()
    // Expose methods on window for inline handlers / turbo compatibility
    window.addAdditionRow = () => this.addAddition()
    window.addDiscountRow = () => this.addDiscount()
    window.removeFeeRow = (btn) => this.removeRow(btn)
    window.recalculateInvoiceTotals = () => this.recalculate()
  }

  buildUnitOptionsHtml(defaultUnit = "") {
    const units = (this.unitOptionsValue && this.unitOptionsValue.length > 0)
      ? this.unitOptionsValue
      : ["Lần sử dụng", "Phòng", "Tháng", "Người", "Số lượng", "kWh", "m3", "Giờ"]

    return units.map(unit => {
      const isSelected = (unit.toLowerCase() === defaultUnit.toLowerCase() ||
                          (defaultUnit.toLowerCase().includes("lần") && unit.toLowerCase().includes("lần"))) ? "selected" : ""
      return `<option value="${unit}" ${isSelected}>${unit}</option>`
    }).join("")
  }

  addAddition() {
    const container = this.additionContainerTarget
    if (!container) return

    const uid = 'add_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6)
    const tr = document.createElement("tr")
    tr.className = "item-row addition-row align-middle fee-row-animated"
    tr.setAttribute("data-item-type", "addition")
    tr.innerHTML = `
      <td class="ps-3 text-center">
        <input type="hidden" name="invoice[items][${uid}][selected]" value="0" />
        <input type="checkbox" name="invoice[items][${uid}][selected]" value="1" checked class="form-check-input item-select-check" data-action="change->invoice-items#recalculate" />
        <input type="hidden" name="invoice[items][${uid}][item_type]" value="addition" class="item-type-val" />
      </td>
      <td>
        <input type="text" name="invoice[items][${uid}][name]" placeholder="${this.additionPlaceholderValue}" class="form-control form-control-sm item-name" />
      </td>
      <td>
        <select name="invoice[items][${uid}][unit]" class="form-select form-select-sm text-center item-unit">
          ${this.buildUnitOptionsHtml("Lần sử dụng")}
        </select>
      </td>
      <td>
        <input type="number" min="0" step="1000" name="invoice[items][${uid}][unit_price]" value="0" class="form-control form-control-sm font-monospace text-end item-price" data-action="input->invoice-items#calculateRow" style="max-width: 120px;" />
      </td>
      <td>
        <input type="number" min="0" step="0.1" name="invoice[items][${uid}][quantity]" value="1" class="form-control form-control-sm font-monospace text-center item-qty" data-action="input->invoice-items#calculateRow" style="max-width: 90px;" />
      </td>
      <td class="text-end">
        <input type="number" readonly="readonly" name="invoice[items][${uid}][amount]" value="0" class="form-control form-control-sm font-monospace text-end item-amount fw-bold text-primary bg-light-subtle" style="max-width: 130px; display: inline-block;" />
      </td>
      <td class="text-center pe-3">
        <button type="button" class="btn btn-sm btn-outline-danger btn-remove-row p-1 d-inline-flex align-items-center justify-content-center" data-action="click->invoice-items#removeRowClick" title="${this.deleteTextValue}" style="width: 28px; height: 28px;">
          <span class="material-symbols-outlined fs-6">delete</span>
        </button>
      </td>
    `
    container.appendChild(tr)
    const nameInput = tr.querySelector(".item-name")
    if (nameInput) nameInput.focus()
    this.recalculate()
  }

  addDiscount() {
    const container = this.discountContainerTarget
    if (!container) return

    const uid = 'disc_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6)
    const tr = document.createElement("tr")
    tr.className = "item-row discount-row align-middle fee-row-animated"
    tr.setAttribute("data-item-type", "discount")
    tr.innerHTML = `
      <td class="ps-3 text-center">
        <input type="hidden" name="invoice[items][${uid}][selected]" value="0" />
        <input type="checkbox" name="invoice[items][${uid}][selected]" value="1" checked class="form-check-input item-select-check" data-action="change->invoice-items#recalculate" />
        <input type="hidden" name="invoice[items][${uid}][item_type]" value="discount" class="item-type-val" />
      </td>
      <td>
        <input type="text" name="invoice[items][${uid}][name]" placeholder="${this.discountPlaceholderValue}" class="form-control form-control-sm item-name text-danger" />
      </td>
      <td>
        <select name="invoice[items][${uid}][unit]" class="form-select form-select-sm text-center item-unit text-danger">
          ${this.buildUnitOptionsHtml("Lần sử dụng")}
        </select>
      </td>
      <td>
        <input type="number" min="0" step="1000" name="invoice[items][${uid}][unit_price]" value="0" class="form-control form-control-sm font-monospace text-end item-price text-danger" data-action="input->invoice-items#calculateRow" style="max-width: 120px;" />
      </td>
      <td>
        <input type="number" min="0" step="0.1" name="invoice[items][${uid}][quantity]" value="1" class="form-control form-control-sm font-monospace text-center item-qty" data-action="input->invoice-items#calculateRow" style="max-width: 90px;" />
      </td>
      <td class="text-end">
        <input type="number" readonly="readonly" name="invoice[items][${uid}][amount]" value="0" class="form-control form-control-sm font-monospace text-end item-amount fw-bold text-danger bg-light-subtle" style="max-width: 130px; display: inline-block;" />
      </td>
      <td class="text-center pe-3">
        <button type="button" class="btn btn-sm btn-outline-danger btn-remove-row p-1 d-inline-flex align-items-center justify-content-center" data-action="click->invoice-items#removeRowClick" title="${this.deleteTextValue}" style="width: 28px; height: 28px;">
          <span class="material-symbols-outlined fs-6">delete</span>
        </button>
      </td>
    `
    container.appendChild(tr)
    const nameInput = tr.querySelector(".item-name")
    if (nameInput) nameInput.focus()
    this.recalculate()
  }

  removeRowClick(event) {
    this.removeRow(event.currentTarget)
  }

  removeRow(target) {
    const btn = target instanceof Event ? target.currentTarget : target
    const row = btn?.closest(".item-row")
    if (row) {
      row.classList.add("fee-row-removing")
      setTimeout(() => {
        row.remove()
        this.recalculate()
      }, 180)
    }
  }

  calculateRow(event) {
    const target = event.target
    const row = target.closest(".item-row")
    if (!row) return

    const priceInput = row.querySelector(".item-price")
    const qtyInput = row.querySelector(".item-qty")
    const amountInput = row.querySelector(".item-amount")
    const prevInput = row.querySelector(".item-prev-reading")
    const latestInput = row.querySelector(".item-latest-reading")

    if (target.classList.contains("item-prev-reading") || target.classList.contains("item-latest-reading")) {
      const prev = prevInput ? (parseFloat(prevInput.value) || 0) : 0
      const latest = latestInput ? (parseFloat(latestInput.value) || 0) : 0
      const price = priceInput ? (parseFloat(priceInput.value) || 0) : 0
      const usage = Math.max(0, latest - prev)
      if (qtyInput) qtyInput.value = usage
      if (amountInput) amountInput.value = Math.round(usage * price)
    } else {
      const price = priceInput ? (parseFloat(priceInput.value) || 0) : 0
      const qty = qtyInput ? (parseFloat(qtyInput.value) || 0) : 0
      if (amountInput) amountInput.value = Math.round(price * qty)
    }

    this.recalculate()
  }

  recalculate() {
    let subtotal = 0
    let totalAddition = 0
    let totalDiscount = 0

    const rows = this.element.querySelectorAll(".item-row")
    rows.forEach(row => {
      const check = row.querySelector(".item-select-check")
      const isSelected = check ? check.checked : true
      const typeInput = row.querySelector(".item-type-val") || row.querySelector("input[name*='[item_type]']")
      const itemType = typeInput ? typeInput.value : (row.getAttribute("data-item-type") || "fixed_service")
      const amountInput = row.querySelector(".item-amount")
      const amount = amountInput ? (parseFloat(amountInput.value) || 0) : 0

      if (!isSelected) return

      if (itemType === "addition") {
        totalAddition += Math.abs(amount)
      } else if (itemType === "discount") {
        totalDiscount += Math.abs(amount)
      } else {
        subtotal += amount
      }
    })

    const grandTotal = Math.max(0, subtotal + totalAddition - totalDiscount)

    if (this.hasSubtotalSummaryTarget) this.subtotalSummaryTarget.textContent = this.formatCurrency(subtotal)
    if (this.hasAdditionSummaryTarget) this.additionSummaryTarget.textContent = "+ " + this.formatCurrency(totalAddition)
    if (this.hasDiscountSummaryTarget) this.discountSummaryTarget.textContent = "- " + this.formatCurrency(totalDiscount)
    if (this.hasTotalSummaryTarget) this.totalSummaryTarget.textContent = this.formatCurrency(grandTotal)
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('vi-VN').format(Math.round(amount || 0)) + ' đ'
  }
}
