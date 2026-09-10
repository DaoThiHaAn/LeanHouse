import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: { type: String, default: "/notifications/box" }
  }

  connect() {
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this)
    document.addEventListener("visibilitychange", this.handleVisibilityChange)
    window.addEventListener("turbo:cable-stream-connected", this.handleVisibilityChange)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.handleVisibilityChange)
    window.removeEventListener("turbo:cable-stream-connected", this.handleVisibilityChange)
  }

  handleVisibilityChange() {
    if (document.visibilityState === "visible") {
      this.sync()
    }
  }

  async sync() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      if (response.ok) {
        const html = await response.text()
        if (html && html.trim().length > 0) {
          this.element.innerHTML = html
        }
      }
    } catch (err) {
      // Silent catch to prevent console noise if user navigates away or network blips
    }
  }
}
