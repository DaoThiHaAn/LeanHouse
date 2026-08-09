import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.syncUrlFromFrame()
  }

  syncUrlFromFrame() {
    const frame = this.element
    const currentUrl = new URL(window.location.href)
    const pageParam = currentUrl.searchParams.get("page")

    if (pageParam) {
      frame.setAttribute("data-page", pageParam)
    }
  }

  updateUrl(event) {
    const frame = event.target
    const page = frame?.getAttribute("data-page") || new URL(frame.src || window.location.href).searchParams.get("page")

    if (page) {
      const currentUrl = new URL(window.location.href)
      currentUrl.searchParams.set("page", page)
      window.history.replaceState({}, "", currentUrl)
    }
  }
}
