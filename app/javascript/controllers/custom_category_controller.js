import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "customContainer", "customInput"]

  connect() {
    console.log("Custom catefory controller connected!")
    this.toggle()
  }

  toggle() {
    const isOther = this.selectTarget.value === "other"
    
    if (isOther) {
      this.customContainerTarget.classList.remove("d-none")
      this.customInputTarget.required = true
      this.customInputTarget.disabled = false
      this.customInputTarget.focus()
    } else {
      this.customContainerTarget.classList.add("d-none")
      this.customInputTarget.required = false
      this.customInputTarget.disabled = true
      this.customInputTarget.value = ""
    }
  }
}