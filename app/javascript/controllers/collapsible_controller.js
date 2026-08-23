import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["expanded", "collapsed"]

  toggle() {
    this.element.classList.toggle("is-collapsed")
    this.expandedTarget.classList.toggle("d-none")
    this.collapsedTarget.classList.toggle("d-none")
    this.collapsedTarget.classList.toggle("d-flex")
  }
}