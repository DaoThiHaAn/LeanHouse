import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "container"]

  preview() {
    const file = this.inputTarget.files[0]
    if (file && file.type.startsWith("image/")) {
      if (this.hasPreviewTarget) {
        this.previewTarget.src = URL.createObjectURL(file)
      }
      if (this.hasContainerTarget) {
        this.containerTarget.classList.remove("d-none")
      }
    }
  }

  clear() {
    this.inputTarget.value = ""
    if (this.hasPreviewTarget) {
      this.previewTarget.src = ""
    }
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add("d-none")
    }
  }
}
