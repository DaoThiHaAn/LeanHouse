import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String
  }
  static targets = ["saveOrderBtn"]

  connect() {
    console.log("Sortable controller connected!")

    this.hasChanges = false

    const list = document.getElementById("floor_list")

    this.sortable = Sortable.create(list, {
      draggable: "turbo-frame",
      handle: ".drag-handle",
      animation: 150,
      onEnd: this.reordered.bind(this)
    })
  }

  reordered() {
    this.hasChanges = true
    this.updateNumbers()
    this.saveOrderBtnTarget.disabled = false 
  }

  updateNumbers() {
    this.element.querySelectorAll(".floor-bar").forEach((row, index) => {
      row.querySelector(".fw-bold").textContent = `${index + 1}.`
    })
  }

  async saveOrder() {
    if (!this.hasChanges) return

    const ids = [...this.element.querySelectorAll(".floor-bar")].map(
      e => e.dataset.id
    )

    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Accept": "text/vnd.turbo-stream.html", // request turbo stream
        "Content-Type": "application/json",
        "X-CSRF-Token":
          document.querySelector("[name=csrf-token]").content
      },
      body: JSON.stringify({
        floor_ids: ids
      })
    })

    if (response.ok) {
      Turbo.renderStreamMessage(await response.text())
      this.hasChanges = false
      this.saveOrderBtnTarget.disabled = true
    }
  }

  disconnect() {
    this.sortable?.destroy()
  }
}