import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["time"]
  static values = { duration: Number }

  connect() {
    this.remaining = this.durationValue
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  tick() {
    if (this.remaining <= 0) {
      this.timeTarget.textContent = "OTP expired"
      clearInterval(this.interval)
      lert("Mã OTP đã hết hạn! Hãy yêu cầu Gửi lại OTP")
      return
    }

    const minutes = Math.floor(this.remaining / 60)
    const seconds = this.remaining % 60

    this.timeTarget.textContent =
      `${minutes}:${seconds.toString().padStart(2, "0")}`

    this.remaining--
  }
}
