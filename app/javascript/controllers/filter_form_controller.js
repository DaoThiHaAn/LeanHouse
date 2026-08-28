import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "clearButton",
    "houseSelect",
    "monthSelect",
    "yearSelect",
    "statusSelect",
    "requestTypeSelect"
  ]

  static values = {
    defaultHouse: { type: String, default: "" }
  }

  connect() {
    this.updateClearButton()
  }

  changed() {
    this.updateClearButton()
    this.element.requestSubmit()
  }

  clear() {
    if (this.hasHouseSelectTarget) {
      this.houseSelectTarget.value = this.defaultHouseValue || ""
    }
    if (this.hasMonthSelectTarget) {
      this.monthSelectTarget.value = ""
    }
    if (this.hasYearSelectTarget) {
      this.yearSelectTarget.value = ""
    }
    if (this.hasStatusSelectTarget) {
      this.statusSelectTarget.value = ""
    }
    if (this.hasRequestTypeSelectTarget) {
      this.requestTypeSelectTarget.value = ""
    }

    this.updateClearButton()
    this.element.requestSubmit()
  }

  updateClearButton() {
    if (!this.hasClearButtonTarget) return

    const defaultHouse = this.defaultHouseValue || ""
    const currentHouse = this.hasHouseSelectTarget ? this.houseSelectTarget.value : ""
    const currentMonth = this.hasMonthSelectTarget ? this.monthSelectTarget.value : ""
    const currentYear = this.hasYearSelectTarget ? this.yearSelectTarget.value : ""
    const currentStatus = this.hasStatusSelectTarget ? this.statusSelectTarget.value : ""
    const currentType = this.hasRequestTypeSelectTarget ? this.requestTypeSelectTarget.value : ""

    const isFiltered = (currentHouse !== defaultHouse) ||
                       (currentMonth !== "") ||
                       (currentYear !== "") ||
                       (currentStatus !== "") ||
                       (currentType !== "")

    if (isFiltered) {
      this.clearButtonTarget.classList.remove("d-none")
    } else {
      this.clearButtonTarget.classList.add("d-none")
    }
  }
}

