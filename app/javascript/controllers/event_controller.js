import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    name: String,
    detail: String
  }

  connect() {
    console.log("Event controller is connected!")

    window.dispatchEvent(
      new CustomEvent(this.nameValue, {
        detail: JSON.parse(this.detailValue || "{}")
      })
    )

    this.element.remove()
  }
}