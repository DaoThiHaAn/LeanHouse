import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.modal = new bootstrap.Modal(this.element)
    this.modal.show()
  }

  disconnect() {
    // Clean up backdrop and state when Turbo frame updates or leaves
    if (this.modal) {
      this.modal.hide()
      this.modal.dispose()
    }
  }
}