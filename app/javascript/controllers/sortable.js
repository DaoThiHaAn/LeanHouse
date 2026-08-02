import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {

  static values = {
    url: String
  }

  connect() {

    Sortable.create(this.element, {

      handle: ".drag-handle",

      animation: 150,

      onEnd: this.update.bind(this)
    })
  }

  update() {

    const ids = [...this.element.children].map(e => e.dataset.id)

    fetch(this.urlValue, {

      method: "PATCH",

      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token":
          document.querySelector("[name=csrf-token]").content
      },

      body: JSON.stringify({
        floor_ids: ids
      })
    })
  }
}