import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {

  static values = {
    url: String
  }

  connect() {
    console.log("Sortable controller connected!")

    Sortable.create(this.element, {
      handle: ".drag-handle",
      animation: 150,
      onEnd: this.update.bind(this)
    })
  }

  async update() {
    const ids = [...this.element.children].map(e => e.dataset.id)

    // Send the new positions to the server via AJAX
    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",  // expect a turbo stream
        "Content-Type": "application/json",
        "X-CSRF-Token":
          document.querySelector("[name=csrf-token]").content
      },

      body: JSON.stringify({
        floor_ids: ids
      })
    })

    console.log("Updated order sent to server:", ids)

    if (response.ok) {
      Turbo.renderStreamMessage(await response.text())
    }

  }
}