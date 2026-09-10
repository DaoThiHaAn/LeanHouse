import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: true },
    duration: { type: Number, default: 6000 }
  }

  connect() {
    if (this.autoDismissValue) {
      this.timeout = setTimeout(() => {
        this.close()
      }, this.durationValue)
    }
  }

  disconnect() {
    this.clearTimer()
  }

  clearTimer() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }

    this.clearTimer()

    if (this.closing) return
    this.closing = true

    this.element.classList.add("toast-closing")
    setTimeout(() => {
      this.element.remove()
    }, 200)
  }
}
