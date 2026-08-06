import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.modal = new bootstrap.Modal(this.element)
    this.modal.show()

    this.closeHandler = () => this.modal.hide()

    window.addEventListener("close-modal", this.closeHandler)
  }

  disconnect() {
    window.removeEventListener("close-modal", this.closeHandler)
    this.modal.dispose()
  }
}