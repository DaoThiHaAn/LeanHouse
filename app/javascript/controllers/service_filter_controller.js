import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "emptyMessage"]

  connect() {
    this.filter()
  }

  filter() {
    if (!this.hasInputTarget) return

    const query = this.normalize(this.inputTarget.value.trim())
    let visibleCount = 0

    this.cardTargets.forEach(card => {
      const name = this.normalize(card.dataset.serviceName || card.textContent)
      const matches = name.includes(query)

      card.classList.toggle("d-none", !matches)
      if (matches) visibleCount++
    })

    if (this.hasEmptyMessageTarget) {
      this.emptyMessageTarget.classList.toggle("d-none", visibleCount > 0)
    }
  }

  clear() {
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.filter()
      this.inputTarget.focus()
    }
  }

  normalize(str) {
    return (str || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
  }
}

