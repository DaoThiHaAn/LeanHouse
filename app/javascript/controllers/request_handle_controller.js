import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rejectSection", "reasonInput"]

  toggleReject() {
    if (this.hasRejectSectionTarget) {
      this.rejectSectionTarget.classList.toggle("d-none")
      if (!this.rejectSectionTarget.classList.contains("d-none") && this.hasReasonInputTarget) {
        this.reasonInputTarget.focus()
      }
    }
  }

  hideReject() {
    if (this.hasRejectSectionTarget) {
      this.rejectSectionTarget.classList.add("d-none")
    }
  }

  confirmReject(event) {
    if (this.hasReasonInputTarget && !this.reasonInputTarget.value.trim()) {
      event.preventDefault()
      this.reasonInputTarget.focus()
      this.reasonInputTarget.classList.add("is-invalid")
    } else if (this.hasReasonInputTarget) {
      this.reasonInputTarget.classList.remove("is-invalid")
    }
  }
}

