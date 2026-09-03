import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    copiedText: { type: String, default: "Đã chép!" },
    originalText: { type: String, default: "Sao chép" },
    duration: { type: Number, default: 2000 }
  }

  copy() {
    const text = this.hasSourceTarget ? (this.sourceTarget.value || this.sourceTarget.innerText) : ""
    if (!text) return

    navigator.clipboard.writeText(text.trim()).then(() => {
      if (this.hasButtonTarget) {
        const btn = this.buttonTarget
        const prevText = btn.innerText
        btn.innerText = this.copiedTextValue
        setTimeout(() => {
          btn.innerText = prevText || this.originalTextValue
        }, this.durationValue)
      }
    })
  }
}
