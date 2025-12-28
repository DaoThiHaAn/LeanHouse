import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-input"
export default class extends Controller {
  static targets = ["input", "removeBtn"]

  connect() {
    this.updateRemoveButton()
  }

  updateRemoveButton() {
    if (this.inputTarget.files.length > 0) {
      this.removeBtnTarget.classList.remove("d-none")
    } else {
      this.removeBtnTarget.classList.add("d-none")
    }
  }

  clearFile() {
    this.inputTarget.value = ""
    this.updateRemoveButton()
  }
}
