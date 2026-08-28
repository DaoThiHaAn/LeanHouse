import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  connect() {
    this.update()
  }

  update() {
    const length = this.inputTarget.value ? this.inputTarget.value.length : 0
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${length}/${this.maxValue}`
    }
  }
}

