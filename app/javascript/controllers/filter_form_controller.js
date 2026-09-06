import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "clearButton",
    "houseSelect",
    "monthSelect",
    "yearSelect",
    "statusSelect",
    "requestTypeSelect",
    "fromInput",
    "toInput"
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
    if (this.hasFromInputTarget) {
      this.fromInputTarget.value = ""
    }
    if (this.hasToInputTarget) {
      this.toInputTarget.value = this.toInputTarget.dataset.defaultValue || ""
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
    const currentFrom = this.hasFromInputTarget ? this.fromInputTarget.value : ""
    const currentTo = this.hasToInputTarget ? this.toInputTarget.value : ""
    const defaultTo = this.hasToInputTarget ? (this.toInputTarget.dataset.defaultValue || "") : ""

    const isFiltered = (currentHouse !== defaultHouse) ||
                       (currentMonth !== "") ||
                       (currentYear !== "") ||
                       (currentStatus !== "") ||
                       (currentType !== "") ||
                       (currentFrom !== "") ||
                       (currentTo !== defaultTo && currentTo !== "")

    if (isFiltered) {
      this.clearButtonTarget.classList.remove("d-none")
    } else {
      this.clearButtonTarget.classList.add("d-none")
    }
  }
}
