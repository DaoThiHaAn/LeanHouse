import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("TOC controller connected!")
    
    this.links = this.element.querySelectorAll(".title-toc")

    this.observer = new IntersectionObserver(
      this.handleIntersect.bind(this),
      {
        threshold: 0.3
      }
    )

    this.links.forEach(link => {
      const section = document.querySelector(link.getAttribute("href"))
      if (section) this.observer.observe(section)
    })
  }

  disconnect() {
    this.observer.disconnect()
  }

  handleIntersect(entries) {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return

      this.links.forEach(link => link.classList.remove("active"))

      const link = this.element.querySelector(
        `[href="#${entry.target.id}"]`
      )

      if (link) link.classList.add("active")
    })
  }
}