import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden", "form"]
  static values = { length: Number }

  input(e) {
    const input = e.target
    input.value = input.value.replace(/\D/g, "")

    if (input.value && this.next(input)) {
      this.next(input).focus()
    }

    this.updateHidden()
  }

  keydown(e) {
    if (e.key === "Backspace" && !e.target.value && this.previous(e.target)) {
      this.previous(e.target).focus()
    }
  }

  updateHidden() {
    const code = this.digitTargets.map(i => i.value).join("")
    this.hiddenTarget.value = code

    if (code.length === this.lengthValue) {
      this.formTarget.requestSubmit()
    }
  }

  next(input) {
    return this.digitTargets[this.digitTargets.indexOf(input) + 1]
  }

  previous(input) {
    return this.digitTargets[this.digitTargets.indexOf(input) - 1]
  }
}
