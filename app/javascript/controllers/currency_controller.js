import { Controller } from "@hotwired/stimulus"
import AutoNumeric from "autonumeric"

export default class extends Controller {
  connect() {
    this.autoNumeric = new AutoNumeric(this.element, {
      digitGroupSeparator: ",",
      decimalPlaces: 0,
      unformatOnSubmit: true // Tells AutoNumeric to strip commas cleanly right before submission
    })
  }

  disconnect() {
    if (this.autoNumeric) {
      this.autoNumeric.remove()
    }
  }
}