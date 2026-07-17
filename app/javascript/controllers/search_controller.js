import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  debounce() {
    clearTimeout(this.timeout)
    // query each 2 seconds
    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, 2000)
  }
}