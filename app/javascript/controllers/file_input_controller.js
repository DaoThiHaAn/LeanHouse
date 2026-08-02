import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-input"
export default class extends Controller {
  static targets = [
    "input",
    "removeBtn",
    "currentFile",
    "fileInput",
    "removeExistingInput"
  ]

  static values = {
    confirmMessage: String
  }

  connect() {
    if (this.hasInputTarget) {
      this.updateRemoveButton()
    }
  }

  updateRemoveButton() {
    if (!this.hasInputTarget) return

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

  removeExistingFile() {
    if (!window.confirm(this.confirmMessageValue)) return

    this.currentFileTarget.classList.add("d-none")
    this.fileInputTarget.classList.remove("d-none")
    this.removeExistingInputTarget.value = "1"
  }
}