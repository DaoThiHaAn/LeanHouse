import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoOpen: Boolean // default is Fasle, set to True to make modal auto-opened
  }

  connect() {
    this.modal = new bootstrap.Modal(this.element)
    if (this.autoOpenValue) {
      this.modal.show()
    }

    this.closeHandler = () => this.modal.hide()

    window.addEventListener("close-modal", this.closeHandler)
  }

  disconnect() {
    window.removeEventListener("close-modal", this.closeHandler)
    this.modal.dispose()
  }

  close() {
    this.modal.hide()
  }
}