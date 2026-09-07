import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "countDisplay", "searchInput", "tenantItem"]

  connect() {
    this.updateCount()
  }

  updateCount() {
    if (!this.hasCountDisplayTarget) return
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked).length
    this.countDisplayTarget.textContent = checkedCount
  }

  selectAll(event) {
    if (event) event.preventDefault()
    this.checkboxTargets.forEach(cb => {
      const item = cb.closest("[data-tenant-selection-target='tenantItem']")
      if (!item || !item.classList.contains("d-none")) {
        cb.checked = true
      }
    })
    this.updateCount()
  }

  deselectAll(event) {
    if (event) event.preventDefault()
    this.checkboxTargets.forEach(cb => {
      cb.checked = false
    })
    this.updateCount()
  }

  toggle(event) {
    this.updateCount()
  }

  filter(event) {
    if (!this.hasSearchInputTarget) return
    const query = this.searchInputTarget.value.trim().toLowerCase()

    this.tenantItemTargets.forEach(item => {
      const searchText = (item.getAttribute("data-search-text") || item.textContent).toLowerCase()
      if (!query || searchText.includes(query)) {
        item.classList.remove("d-none")
      } else {
        item.classList.add("d-none")
      }
    })
  }
}
