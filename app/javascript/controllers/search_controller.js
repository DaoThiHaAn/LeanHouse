import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    console.log("Search controller connected")
  }

  debounce() {
    clearTimeout(this.timeout)
    // query each 0.8 seconds
    this.timeout = setTimeout(() => {
        console.log("Submitting...")
        this.element.requestSubmit()
    }, 800)
  }
}