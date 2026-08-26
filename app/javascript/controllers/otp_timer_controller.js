import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["time"]
  static values = { expiresAt: Number }

  connect() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  tick() {
    const now = Date.now()
    const remaining = Math.max(0, Math.floor((this.expiresAtValue - now) / 1000))

    if (remaining <= 0) {
      this.timeTarget.textContent = "Mã OTP đã hết hạn! Vui lòng chọn Gửi lại OTP."
      this.timeTarget.classList.add("text-danger")
      if (this.interval) {
        clearInterval(this.interval)
      }
      return
    }

    const minutes = Math.floor(remaining / 60)
    const seconds = remaining % 60

    this.timeTarget.classList.remove("text-danger")
    this.timeTarget.textContent =
      `${minutes}:${seconds.toString().padStart(2, "0")}`
  }
}
