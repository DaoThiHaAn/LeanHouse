import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // default value (matches "selected" class)
    this.inputTarget.value = "tenant"
    console.log("Role selector connected")
  }

  select(event) {
    const selected = event.currentTarget.dataset.roleSelectorValue
    console.log("Selected role:", selected)

    // remove selected class from all
    this.element
      .querySelectorAll(".role-option")
      .forEach(el => el.classList.remove("selected"))

    // add selected class
    event.currentTarget.classList.add("selected")

    // update hidden field
    this.inputTarget.value = selected
  }
}
