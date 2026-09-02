import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  select(event) {
    const clickedLink = event.currentTarget
    this.linkTargets.forEach((link) => {
      link.classList.remove("active")
    })
    clickedLink.classList.add("active")
  }
}

