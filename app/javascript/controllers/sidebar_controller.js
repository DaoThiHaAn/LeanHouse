import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

  connect() {
    console.log("Sidebar controller connected!")
    const collapsed = localStorage.getItem("sidebarCollapsed") === "true"

    if (collapsed) {
      this.sidebarTarget.classList.add("collapsed")
    }
  }

  toggle() {
    this.sidebarTarget.classList.toggle("collapsed")

    const collapsed =
      this.sidebarTarget.classList.contains("collapsed")

    localStorage.setItem("sidebarCollapsed", collapsed)
  }
}