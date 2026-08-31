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
    if (this.modal) {
      this.modal.hide()
      this.modal.dispose()
    }
    document.querySelectorAll(".modal-backdrop").forEach(el => el.remove())
    document.body.classList.remove("modal-open")
    document.body.style.removeProperty("overflow")
    document.body.style.removeProperty("padding-right")
  }

  close() {
    if (this.modal) {
      this.modal.hide()
    }
  }
}