import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label"]

  static values = {
    roomLabel: String,
    bedLabel: String
  }

  updateLabel(event) {
    const mode = event.detail.mode

    this.labelTarget.textContent =
      mode === "room"
        ? this.roomLabelValue
        : this.bedLabelValue
  }
}